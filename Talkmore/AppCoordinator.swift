import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppCoordinator {
    private(set) var state: DictationState = .idle
    private(set) var liveTranscript = ""
    private(set) var lastTranscript = ""
    private(set) var lastLatencySummary = ""
    private(set) var lastCompatibilitySummary = ""
    private(set) var lastDiagnostic = "Starting…"
    private(set) var isHotkeyRunning = false
    var refinementEnabled: Bool {
        didSet { UserDefaults.standard.set(refinementEnabled, forKey: "refinementEnabled") }
    }
    var developerModeEnabled: Bool {
        didSet { UserDefaults.standard.set(developerModeEnabled, forKey: "developerModeEnabled") }
    }

    let permissions = PermissionManager()
    let refiner = AppleTextRefiner()

    private let hotkey = PushToTalkMonitor()
    private let inserter = TextInserter()
    private let overlay = OverlayController()
    private var activeDictation: AppleDictationService?
    private var activeSessionID: UUID?
    private var activeWritingContext = WritingContext.standard
    private var target: TextTarget?
    private var shortcutHeld = false
    private var hasStarted = false
    private var preparedDictationTask: Task<AppleDictationService?, Never>?
    private let logger = Logger(subsystem: "com.mithul.talkmore", category: "Dictation")
#if DEBUG
    private var diagnosticSignalSources: [DispatchSourceSignal] = []
#endif

    init() {
        refinementEnabled = UserDefaults.standard.object(forKey: "refinementEnabled") as? Bool ?? true
        developerModeEnabled = UserDefaults.standard.object(forKey: "developerModeEnabled") as? Bool ?? true
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        hotkey.onPress = { [weak self] in
            guard let self else { return }
            self.trace("Fn press received")
            Task { await self.beginDictation() }
        }
        hotkey.onRelease = { [weak self] in
            guard let self else { return }
            self.trace("Fn release received")
            Task { await self.endDictation() }
        }
        hotkey.start()
        isHotkeyRunning = true
        permissions.refresh()
        trace("Ready · \(permissionSummary)")
        if refinementEnabled { refiner.prepare() }
        primeDictationService()
#if DEBUG
        installDiagnosticSignals()
#endif

        // Local development builds are ad-hoc signed when no Development Team
        // is configured. macOS can drop Input Monitoring or Accessibility after
        // a rebuild, so recover the permission flow instead of silently leaving
        // the fn hotkey inactive.
        if !permissions.allRequiredPermissionsGranted {
            Task { await requestPermissions() }
        }
    }

    func requestPermissions() async {
        await permissions.requestAll()
        permissions.refresh()
        trace("Permissions refreshed · \(permissionSummary)")
    }

    func retryAfterError() {
        state = .idle
        liveTranscript = ""
        overlay.hide()
    }

    private func beginDictation() async {
        shortcutHeld = true
        guard !state.isBusy else { return }
        if case .error = state { state = .idle }

        permissions.refresh()
        guard permissions.microphoneGranted, permissions.speechGranted else {
            fail("Microphone and Speech Recognition permissions are required. Open Talkmore from the menu bar to grant them.")
            return
        }

        state = .preparing
        trace("Preparing microphone")
        liveTranscript = ""
        target = inserter.captureTarget()
        activeWritingContext = target.map {
            WritingContext(target: $0, developerModeEnabled: developerModeEnabled)
        } ?? .standard
        overlay.show(state: state)
        if refinementEnabled { refiner.prepare() }

        let sessionID = UUID()
        let dictation = await nextDictationService()
        activeSessionID = sessionID
        activeDictation = dictation

        do {
            try await dictation.start(
                contextualStrings: activeWritingContext.speechHints,
                onTranscript: { [weak self] transcript in
                    guard let self, self.activeSessionID == sessionID else { return }
                    if self.liveTranscript.isEmpty, !transcript.isEmpty {
                        self.trace("Speech recognized")
                    }
                    self.liveTranscript = transcript
                },
                onAudioLevel: { [weak self] level in
                    guard let self, self.activeSessionID == sessionID else { return }
                    self.overlay.update(audioLevel: level)
                }
            )

            state = .recording
            trace("Recording")
            overlay.update(state: state)
            primeDictationService()
            if !shortcutHeld { await endDictation() }
        } catch {
            activeSessionID = nil
            activeDictation = nil
            await dictation.cancel()
            primeDictationService()
            fail(error.localizedDescription)
        }
    }

    private func endDictation() async {
        shortcutHeld = false
        guard
            state == .recording,
            let dictation = activeDictation,
            let insertionTarget = target
        else { return }
        let writingContext = activeWritingContext

        state = .finalizing
        trace("Finalizing speech")
        overlay.update(state: state, audioLevel: 0)
        let releaseTime = CFAbsoluteTimeGetCurrent()

        do {
            try dictation.stopCapturing()
            let transcriptAtRelease = liveTranscript
            let finalizationTask = Task {
                try await dictation.finalizeTranscription()
            }

            // Finalization is already running while we wait for the latest
            // streaming result. Settle early after a trailing update, or use a
            // hard 330 ms deadline to preserve sub-0.5-second visible latency.
            let settledTranscript = await waitForTrailingTranscript(startingWith: transcriptAtRelease)
            let provisional = writingContext.process(FastTextCleaner.clean(settledTranscript))
            activeSessionID = nil
            activeDictation = nil

            if !provisional.isEmpty {
                state = .inserting
                overlay.update(state: state, transcript: provisional)
                let receipt = try await inserter.insert(provisional, into: insertionTarget)
                trace("Text inserted · \(receipt.route.rawValue)")
                let visibleTime = CFAbsoluteTimeGetCurrent() - releaseTime
                lastTranscript = provisional
                recordCompatibility(target: insertionTarget, receipt: receipt)
                lastLatencySummary = String(format: "Visible %.2fs · Polishing…", visibleTime)
                finish()

                Task { [weak self] in
                    await self?.finalizeAndPolish(
                        dictation: dictation,
                        finalizationTask: finalizationTask,
                        receipt: receipt,
                        provisional: provisional,
                        writingContext: writingContext,
                        releaseTime: releaseTime,
                        visibleTime: visibleTime
                    )
                }
                return
            }

            // Very short utterances occasionally have no volatile result. In
            // that case wait only for final speech recognition, insert it, and
            // still keep generative cleanup off the blocking path.
            let finalTranscript = writingContext.process(
                FastTextCleaner.clean(try await finalizationTask.value)
            )
            guard !finalTranscript.isEmpty else {
                finish()
                return
            }
            state = .inserting
            overlay.update(state: state, transcript: finalTranscript)
            let receipt = try await inserter.insert(finalTranscript, into: insertionTarget)
            trace("Text inserted · \(receipt.route.rawValue)")
            let visibleTime = CFAbsoluteTimeGetCurrent() - releaseTime
            lastTranscript = finalTranscript
            recordCompatibility(target: insertionTarget, receipt: receipt)
            lastLatencySummary = String(format: "Visible %.2fs · Polishing…", visibleTime)
            finish()

            Task { [weak self] in
                await self?.polishKnownTranscript(
                    finalTranscript,
                    receipt: receipt,
                    provisional: finalTranscript,
                    writingContext: writingContext,
                    releaseTime: releaseTime,
                    visibleTime: visibleTime
                )
            }
        } catch {
            activeSessionID = nil
            activeDictation = nil
            await dictation.cancel()
            fail(error.localizedDescription)
        }
    }

    private func finalizeAndPolish(
        dictation: AppleDictationService,
        finalizationTask: Task<String, Error>,
        receipt: TextInsertionReceipt,
        provisional: String,
        writingContext: WritingContext,
        releaseTime: CFAbsoluteTime,
        visibleTime: CFTimeInterval
    ) async {
        do {
            let finalTranscript = writingContext.process(
                FastTextCleaner.clean(try await finalizationTask.value)
            )
            guard !finalTranscript.isEmpty else {
                lastLatencySummary = String(format: "Visible %.2fs", visibleTime)
                return
            }
            await polishKnownTranscript(
                finalTranscript,
                receipt: receipt,
                provisional: provisional,
                writingContext: writingContext,
                releaseTime: releaseTime,
                visibleTime: visibleTime
            )
        } catch {
            await dictation.cancel()
            lastLatencySummary = String(format: "Visible %.2fs · Finalization skipped", visibleTime)
        }
    }

    private func waitForTrailingTranscript(startingWith transcriptAtRelease: String) async -> String {
        let started = CFAbsoluteTimeGetCurrent()
        var latest = liveTranscript
        var observedTrailingUpdate = latest != transcriptAtRelease
        var stableTicks = 0

        while CFAbsoluteTimeGetCurrent() - started < 0.33 {
            try? await Task.sleep(nanoseconds: 30_000_000)
            let current = liveTranscript
            if current != latest {
                latest = current
                observedTrailingUpdate = true
                stableTicks = 0
            } else if observedTrailingUpdate {
                stableTicks += 1
                if stableTicks >= 2, CFAbsoluteTimeGetCurrent() - started >= 0.15 {
                    break
                }
            }
        }
        return latest
    }

    private func polishKnownTranscript(
        _ transcript: String,
        receipt: TextInsertionReceipt,
        provisional: String,
        writingContext: WritingContext,
        releaseTime: CFAbsoluteTime,
        visibleTime: CFTimeInterval
    ) async {
        let refined = refinementEnabled
            ? await refiner.refine(transcript, context: writingContext)
            : transcript
        let polished = writingContext.process(refined)
        let applied = polished == provisional || inserter.replaceIfUnchanged(receipt, with: polished)
        if applied { lastTranscript = polished }
        let finalTime = CFAbsoluteTimeGetCurrent() - releaseTime
        lastLatencySummary = applied
            ? String(format: "Visible %.2fs · Final %.2fs", visibleTime, finalTime)
            : String(format: "Visible %.2fs · Final ready, cursor moved", visibleTime)
    }

    private func finish() {
        state = .idle
        liveTranscript = ""
        target = nil
        activeWritingContext = .standard
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if state == .idle { overlay.hide() }
        }
    }

    private func recordCompatibility(target: TextTarget, receipt: TextInsertionReceipt) {
        let appName = target.applicationName ?? target.bundleIdentifier ?? "Unknown app"
        let mode = activeWritingContext.isDeveloperMode ? " · Developer mode" : ""
        lastCompatibilitySummary = "\(appName) · \(receipt.route.rawValue)\(mode)"
    }

    private func fail(_ message: String) {
        trace("Error · \(message)", level: .error)
        state = .error(message)
        overlay.show(state: state, transcript: message)
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .error = state { retryAfterError() }
        }
    }

    private var permissionSummary: String {
        "mic \(permissions.microphoneGranted ? "yes" : "no"), "
            + "speech \(permissions.speechGranted ? "yes" : "no"), "
            + "accessibility \(permissions.accessibilityGranted ? "yes" : "no"), "
            + "input \(permissions.inputMonitoringGranted ? "yes" : "no")"
    }

    private func trace(_ message: String, level: OSLogType = .info) {
        lastDiagnostic = message
        logger.log(level: level, "\(message, privacy: .public)")
    }

    private func primeDictationService() {
        guard preparedDictationTask == nil else { return }
        preparedDictationTask = Task {
            let service = AppleDictationService()
            do {
                try await service.prepare()
                return service
            } catch {
                return nil
            }
        }
    }

    private func nextDictationService() async -> AppleDictationService {
        guard let preparedDictationTask else { return AppleDictationService() }
        let service = await preparedDictationTask.value
        self.preparedDictationTask = nil
        return service ?? AppleDictationService()
    }

#if DEBUG
    private func installDiagnosticSignals() {
        guard diagnosticSignalSources.isEmpty else { return }
        signal(SIGUSR1, SIG_IGN)
        signal(SIGUSR2, SIG_IGN)

        let press = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        press.setEventHandler { [weak self] in
            guard let self else { return }
            self.trace("Diagnostic press received")
            Task { await self.beginDictation() }
        }

        let release = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
        release.setEventHandler { [weak self] in
            guard let self else { return }
            self.trace("Diagnostic release received")
            Task { await self.endDictation() }
        }

        press.resume()
        release.resume()
        diagnosticSignalSources = [press, release]
    }
#endif
}
