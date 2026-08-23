import Foundation
import Observation

@MainActor
@Observable
final class AppCoordinator {
    private(set) var state: DictationState = .idle
    private(set) var liveTranscript = ""
    private(set) var lastTranscript = ""
    private(set) var lastLatencySummary = ""
    private(set) var lastCompatibilitySummary = ""
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

    init() {
        refinementEnabled = UserDefaults.standard.object(forKey: "refinementEnabled") as? Bool ?? true
        developerModeEnabled = UserDefaults.standard.object(forKey: "developerModeEnabled") as? Bool ?? true
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        hotkey.onPress = { [weak self] in
            guard let self else { return }
            Task { await self.beginDictation() }
        }
        hotkey.onRelease = { [weak self] in
            guard let self else { return }
            Task { await self.endDictation() }
        }
        hotkey.start()
        isHotkeyRunning = true
        permissions.refresh()
        if refinementEnabled { refiner.prepare() }
    }

    func requestPermissions() async {
        await permissions.requestAll()
        permissions.refresh()
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
        liveTranscript = ""
        target = inserter.captureTarget()
        activeWritingContext = target.map {
            WritingContext(target: $0, developerModeEnabled: developerModeEnabled)
        } ?? .standard
        overlay.show(state: state)
        if refinementEnabled { refiner.prepare() }

        let sessionID = UUID()
        let dictation = AppleDictationService()
        activeSessionID = sessionID
        activeDictation = dictation

        do {
            try await dictation.start(
                contextualStrings: activeWritingContext.speechHints,
                onTranscript: { [weak self] transcript in
                    guard let self, self.activeSessionID == sessionID else { return }
                    self.liveTranscript = transcript
                },
                onAudioLevel: { [weak self] level in
                    guard let self, self.activeSessionID == sessionID else { return }
                    self.overlay.update(audioLevel: level)
                }
            )

            state = .recording
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
        state = .error(message)
        overlay.show(state: state, transcript: message)
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .error = state { retryAfterError() }
        }
    }
}
