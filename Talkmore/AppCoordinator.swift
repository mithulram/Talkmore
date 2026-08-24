import Foundation
import Observation
import OSLog
import AppKit

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
    let settings = ProductSettings()
    let personalDictionary = PersonalDictionary()
    let history = DictationHistory()

    private let hotkey = PushToTalkMonitor()
    private let inserter = TextInserter()
    private let automaticDictionaryLearner = AutomaticDictionaryLearner()
    private let overlay = OverlayController()
    private let englishDictation = EnglishDictationService()
    private var activeDictation: EnglishDictationService?
    private var activeSessionID: UUID?
    private var activeWritingContext = WritingContext.standard
    private var target: TextTarget?
    private var shortcutHeld = false
    private var hasStarted = false
    private let logger = Logger(subsystem: "com.mithul.talkmore", category: "Dictation")
#if DEBUG
    private var diagnosticSignalSources: [DispatchSourceSignal] = []
#endif

    init() {
        refinementEnabled = UserDefaults.standard.object(forKey: "refinementEnabled") as? Bool ?? true
        developerModeEnabled = UserDefaults.standard.object(forKey: "developerModeEnabled") as? Bool ?? true
    }

    var recognitionStatusDescription: String {
        englishDictation.statusDescription
    }

    var setupNeedsAttention: Bool {
        !permissions.microphoneGranted
            || !permissions.accessibilityGranted
            || !permissions.inputMonitoringGranted
            || (!permissions.speechGranted && !englishDictation.isHighAccuracyReady)
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
        englishDictation.prime()
#if DEBUG
        installDiagnosticSignals()
#endif

        // Local development builds are ad-hoc signed when no Development Team
        // is configured. macOS can drop Input Monitoring or Accessibility after
        // a rebuild, so recover the permission flow instead of silently leaving
        // the fn hotkey inactive.
        if setupNeedsAttention {
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

    func copyLastTranscript() {
        guard !lastTranscript.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
        trace("Last dictation copied")
    }

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func beginDictation() async {
        shortcutHeld = true
        guard !state.isBusy else { return }
        if case .error = state { state = .idle }

        permissions.refresh()
        guard permissions.microphoneGranted else {
            fail("Microphone permission is required. Open Talkmore from the menu bar to grant it.")
            return
        }
        guard permissions.speechGranted || englishDictation.isHighAccuracyReady else {
            fail("Speech Recognition permission is needed until the high-accuracy English model is ready.")
            return
        }

        state = .preparing
        trace("Preparing microphone")
        liveTranscript = ""
        target = inserter.captureTarget()
        activeWritingContext = target.map {
            WritingContext(
                target: $0,
                developerModeEnabled: developerModeEnabled,
                preferredStyle: settings.writingStyle
            )
        } ?? .standard
        if settings.showOverlay {
            overlay.show(state: state, placement: settings.overlayPlacement)
        }
        if refinementEnabled { refiner.prepare() }

        let sessionID = UUID()
        let dictation = englishDictation
        activeSessionID = sessionID
        activeDictation = dictation

        do {
            try await dictation.start(
                locale: Locale(identifier: "en_US"),
                contextualStrings: activeWritingContext.speechHints + personalDictionary.speechHints,
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
            trace("Recording · \(dictation.engineName)")
            overlay.update(state: state)
            if !shortcutHeld { await endDictation() }
        } catch {
            activeSessionID = nil
            activeDictation = nil
            await dictation.cancel()
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

            // Finalization is already running while we wait for the best Apple
            // result available inside the existing hard 330 ms latency budget.
            let settledTranscript = await waitForTrailingTranscript(
                startingWith: transcriptAtRelease,
                dictation: dictation
            )
            let provisional = processTranscript(settledTranscript, context: writingContext)
            activeSessionID = nil
            activeDictation = nil

            if !provisional.isEmpty {
                state = .inserting
                overlay.update(state: state, transcript: provisional)
                let receipt = try await inserter.insert(provisional, into: insertionTarget)
                trace("Text inserted · \(receipt.route.rawValue)")
                let visibleTime = CFAbsoluteTimeGetCurrent() - releaseTime
                lastTranscript = provisional
                recordSuccessfulInsertion(
                    text: provisional,
                    target: insertionTarget,
                    receipt: receipt,
                    visibleTime: visibleTime,
                    writingContext: writingContext
                )
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
            let finalTranscript = processTranscript(
                try await finalizationTask.value,
                context: writingContext
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
            recordSuccessfulInsertion(
                text: finalTranscript,
                target: insertionTarget,
                receipt: receipt,
                visibleTime: visibleTime,
                writingContext: writingContext
            )
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
        dictation: EnglishDictationService,
        finalizationTask: Task<String, Error>,
        receipt: TextInsertionReceipt,
        provisional: String,
        writingContext: WritingContext,
        releaseTime: CFAbsoluteTime,
        visibleTime: CFTimeInterval
    ) async {
        do {
            let finalTranscript = processTranscript(
                try await finalizationTask.value,
                context: writingContext
            )
            guard !finalTranscript.isEmpty else {
                lastLatencySummary = String(format: "Visible %.2fs", visibleTime)
                startCorrectionLearning(receipt)
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
            startCorrectionLearning(receipt)
        }
    }

    private func waitForTrailingTranscript(
        startingWith transcriptAtRelease: String,
        dictation: EnglishDictationService
    ) async -> String {
        let started = CFAbsoluteTimeGetCurrent()
        var latest = transcriptAtRelease
        var stableTicks = 0

        while CFAbsoluteTimeGetCurrent() - started < 0.33 {
            if dictation.completedTranscript != nil {
                return DictationTranscriptPlanner.bestAvailable(
                    completed: dictation.completedTranscript,
                    live: latest
                )
            }
            try? await Task.sleep(nanoseconds: 30_000_000)
            let current = liveTranscript
            if current != latest {
                latest = current
                stableTicks = 0
            } else {
                stableTicks += 1
                if DictationSettlePlanner.shouldFinishEarly(
                    hasFinalResultAfterCapture: dictation.hasFinalResultAfterCapture,
                    stableTicks: stableTicks,
                    elapsed: CFAbsoluteTimeGetCurrent() - started
                ) {
                    break
                }
            }
        }
        return DictationTranscriptPlanner.bestAvailable(
            completed: dictation.completedTranscript,
            live: latest
        )
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
        let polished = personalDictionary.apply(to: writingContext.process(refined))
        let applied = polished == provisional || inserter.replaceIfUnchanged(receipt, with: polished)
        if applied {
            lastTranscript = polished
            if polished == provisional {
                startCorrectionLearning(receipt)
            } else if let settledReceipt = inserter.refreshedLearningReceipt(
                from: receipt,
                insertedText: polished
            ) {
                startCorrectionLearning(settledReceipt)
            }
        } else {
            // A moved cursor usually means the user started editing before
            // background polishing completed. Observe the original snapshot
            // so that a real correction can still be learned.
            startCorrectionLearning(receipt)
        }
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

    private func processTranscript(_ transcript: String, context: WritingContext) -> String {
        let prepared = context.preprocess(transcript)
        let styled = context.process(prepared)
        return personalDictionary.apply(to: styled)
    }

    private func recordSuccessfulInsertion(
        text: String,
        target: TextTarget,
        receipt: TextInsertionReceipt,
        visibleTime: TimeInterval,
        writingContext: WritingContext
    ) {
        recordCompatibility(target: target, receipt: receipt)
        guard settings.saveHistory else { return }
        history.record(
            text: text,
            applicationName: target.applicationName,
            writingStyle: writingContext.resolvedStyle,
            route: receipt.route,
            visibleLatency: visibleTime
        )
    }

    private func startCorrectionLearning(_ receipt: TextInsertionReceipt) {
        automaticDictionaryLearner.observe(
            receipt: receipt,
            inserter: inserter,
            dictionary: personalDictionary
        )
    }

    private func recordCompatibility(target: TextTarget, receipt: TextInsertionReceipt) {
        let appName = target.applicationName ?? target.bundleIdentifier ?? "Unknown app"
        let style = activeWritingContext.resolvedStyle.title
        lastCompatibilitySummary = "\(appName) · \(receipt.route.rawValue) · \(style)"
    }

    private func fail(_ message: String) {
        trace("Error · \(message)", level: .error)
        state = .error(message)
        if settings.showOverlay {
            overlay.show(
                state: state,
                transcript: message,
                placement: settings.overlayPlacement
            )
        }
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
