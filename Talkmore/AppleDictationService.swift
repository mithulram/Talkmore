@preconcurrency import AVFoundation
import Accelerate
import Speech

private final class AudioConversionInput: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    var wasConsumed = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}

private final class AudioLevelSampler: @unchecked Sendable {
    private var bufferCount = 0
    private let handler: @MainActor (Float) -> Void

    init(handler: @escaping @MainActor (Float) -> Void) {
        self.handler = handler
    }

    func consume(_ buffer: AVAudioPCMBuffer) {
        bufferCount += 1
        guard bufferCount.isMultiple(of: 2),
              let samples = buffer.floatChannelData?.pointee,
              buffer.frameLength > 0 else { return }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(buffer.frameLength))
        let decibels = 20 * log10(max(rms, 0.000_001))
        let normalized = max(0, min(1, (decibels + 55) / 45))
        Task { @MainActor in handler(normalized) }
    }
}

final class BufferedStreamGate<Element: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private let continuation: AsyncStream<Element>.Continuation
    private var bufferedElements: [Element] = []
    private var isOpen = false
    private var isFinished = false

    init(continuation: AsyncStream<Element>.Continuation) {
        self.continuation = continuation
    }

    func yield(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished else {
            return
        }
        if isOpen {
            continuation.yield(element)
        } else {
            bufferedElements.append(element)
        }
    }

    func open() {
        lock.lock()
        defer { lock.unlock() }
        guard !isOpen, !isFinished else { return }
        isOpen = true
        for element in bufferedElements {
            continuation.yield(element)
        }
        bufferedElements.removeAll(keepingCapacity: false)
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished else {
            return
        }
        isFinished = true
        isOpen = true
        for element in bufferedElements {
            continuation.yield(element)
        }
        bufferedElements.removeAll(keepingCapacity: false)
        continuation.finish()
    }
}

enum SpeechContextPlanner {
    static func normalized(_ strings: [String]) -> [String] {
        var seen: Set<String> = []
        return strings.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            guard seen.insert(key).inserted else { return nil }
            return trimmed
        }
    }
}

enum DictationTranscriptPlanner {
    static func bestAvailable(completed: String?, live: String) -> String {
        let completed = completed?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return completed.isEmpty ? live : completed
    }
}

enum DictationSettlePlanner {
    static func shouldFinishEarly(
        hasFinalResultAfterCapture: Bool,
        stableTicks: Int,
        elapsed: TimeInterval
    ) -> Bool {
        hasFinalResultAfterCapture && stableTicks >= 2 && elapsed >= 0.15
    }
}

enum DictationServiceError: LocalizedError {
    case unsupportedLocale
    case missingAudioFormat
    case audioConversionFailed
    case notRecording

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale: "Apple speech recognition does not support the selected language."
        case .missingAudioFormat: "Talkmore could not configure the microphone format."
        case .audioConversionFailed: "Talkmore could not convert microphone audio for transcription."
        case .notRecording: "No recording is currently active."
        }
    }
}

@MainActor
protocol DictationService: AnyObject {
    typealias TranscriptHandler = @MainActor @Sendable (String) -> Void
    typealias AudioLevelHandler = @MainActor @Sendable (Float) -> Void

    var completedTranscript: String? { get }
    var hasFinalResultAfterCapture: Bool { get }
    var engineName: String { get }

    func prepare(locale: Locale) async throws
    func start(
        locale: Locale,
        contextualStrings: [String],
        onTranscript: @escaping TranscriptHandler,
        onAudioLevel: @escaping AudioLevelHandler
    ) async throws
    func stopCapturing() throws
    func finalizeTranscription() async throws -> String
    func cancel() async
}

@MainActor
final class AppleDictationService: DictationService {
    typealias TranscriptHandler = DictationService.TranscriptHandler
    typealias AudioLevelHandler = DictationService.AudioLevelHandler

    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var inputGate: BufferedStreamGate<AnalyzerInput>?
    private var resultTask: Task<Void, Error>?
    private var converter: AVAudioConverter?
    private var preparedFormat: AVAudioFormat?
    private var audioLevelHandler: AudioLevelHandler?
    private var finalizedText = ""
    private var volatileText = ""
    private(set) var completedTranscript: String?
    private(set) var hasFinalResultAfterCapture = false
    private var isRecording = false
    private var isFinalizing = false
    private var tapInstalled = false

    let engineName = "Apple Speech English fallback"

    func prepare(locale requestedLocale: Locale = .current) async throws {
        guard analyzer == nil else { return }

        let preferredLocale = await DictationTranscriber.supportedLocale(equivalentTo: requestedLocale)
        let fallbackLocale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_US"))
        guard let locale = preferredLocale ?? fallbackLocale else {
            throw DictationServiceError.unsupportedLocale
        }

        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installation.downloadAndInstall()
        }
        _ = try? await AssetInventory.reserve(locale: locale)

        let options = SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: options)
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw DictationServiceError.missingAudioFormat
        }
        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let inputGate = BufferedStreamGate(continuation: continuation)
        try await analyzer.start(inputSequence: stream)

        self.analyzer = analyzer
        self.transcriber = transcriber
        self.inputGate = inputGate
        preparedFormat = analyzerFormat
        try configureAudioEngine(
            analyzerFormat: analyzerFormat,
            inputGate: inputGate
        )
    }

    func start(
        locale requestedLocale: Locale = .current,
        contextualStrings: [String] = [],
        onTranscript: @escaping TranscriptHandler,
        onAudioLevel: @escaping AudioLevelHandler
    ) async throws {
        guard !isRecording else { return }

        try await prepare(locale: requestedLocale)
        guard let analyzer, let transcriber, preparedFormat != nil else {
            throw DictationServiceError.missingAudioFormat
        }
        let contextualStrings = SpeechContextPlanner.normalized(contextualStrings)

        self.finalizedText = ""
        self.volatileText = ""
        completedTranscript = nil
        hasFinalResultAfterCapture = false
        isFinalizing = false

        resultTask = Task { [weak self] in
            for try await result in transcriber.results {
                guard let self else { return }
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                self.accept(text: text, isFinal: result.isFinal, handler: onTranscript)
            }
        }

        audioLevelHandler = onAudioLevel
        try audioEngine.start()
        isRecording = true

        // Capture begins immediately, while the gate holds only the first few
        // converted buffers. Opening it after the context update ensures names
        // and technical vocabulary affect the first word without losing audio
        // or adding work to the release-to-insert path.
        defer { inputGate?.open() }
        if !contextualStrings.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = contextualStrings
            // Vocabulary is an accuracy enhancement, never a prerequisite for
            // transcription. Some OS builds can reject context updates while
            // speech assets are changing, so keep the base recognizer running.
            try? await analyzer.setContext(context)
        }
    }

    func stop() async throws -> String {
        try stopCapturing()
        return try await finalizeTranscription()
    }

    func stopCapturing() throws {
        guard isRecording else { throw DictationServiceError.notRecording }
        isRecording = false
        isFinalizing = true

        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine.stop()
        inputGate?.finish()
        inputGate = nil
    }

    func finalizeTranscription() async throws -> String {
        guard let analyzer else { throw DictationServiceError.notRecording }
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        try await resultTask?.value

        let text = combinedTranscript
        completedTranscript = text
        isFinalizing = false
        resultTask = nil
        self.analyzer = nil
        transcriber = nil
        converter = nil
        preparedFormat = nil
        audioLevelHandler = nil
        return text
    }

    func cancel() async {
        isRecording = false
        isFinalizing = false
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine.stop()
        inputGate?.finish()
        inputGate = nil
        await analyzer?.cancelAndFinishNow()
        resultTask?.cancel()
        resultTask = nil
        analyzer = nil
        transcriber = nil
        converter = nil
        preparedFormat = nil
        audioLevelHandler = nil
        completedTranscript = nil
        hasFinalResultAfterCapture = false
    }

    private var combinedTranscript: String {
        [finalizedText, volatileText]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func accept(text: String, isFinal: Bool, handler: TranscriptHandler) {
        if isFinal {
            if isFinalizing { hasFinalResultAfterCapture = true }
            if !text.isEmpty {
                finalizedText = [finalizedText, text].filter { !$0.isEmpty }.joined(separator: " ")
            }
            volatileText = ""
        } else {
            volatileText = text
        }
        handler(combinedTranscript)
    }

    private func configureAudioEngine(
        analyzerFormat: AVAudioFormat,
        inputGate: BufferedStreamGate<AnalyzerInput>
    ) throws {
        let inputNode = audioEngine.inputNode
        let microphoneFormat = inputNode.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: microphoneFormat, to: analyzerFormat) else {
            throw DictationServiceError.audioConversionFailed
        }
        self.converter = converter
        let levelSampler = AudioLevelSampler { [weak self] level in
            self?.audioLevelHandler?(level)
        }

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: microphoneFormat) { buffer, _ in
            levelSampler.consume(buffer)
            guard let converted = Self.convert(buffer, using: converter, to: analyzerFormat) else { return }
            inputGate.yield(AnalyzerInput(buffer: converted))
        }
        tapInstalled = true

        audioEngine.prepare()
    }

    private static func convert(
        _ input: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount((Double(input.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        let conversionInput = AudioConversionInput(buffer: input)
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if conversionInput.wasConsumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            conversionInput.wasConsumed = true
            inputStatus.pointee = .haveData
            return conversionInput.buffer
        }

        guard status != .error, conversionError == nil, output.frameLength > 0 else { return nil }
        return output
    }
}
