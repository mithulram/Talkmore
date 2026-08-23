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
final class AppleDictationService {
    typealias TranscriptHandler = @MainActor (String) -> Void
    typealias AudioLevelHandler = @MainActor (Float) -> Void

    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultTask: Task<Void, Error>?
    private var converter: AVAudioConverter?
    private var finalizedText = ""
    private var volatileText = ""
    private var isRecording = false
    private var tapInstalled = false

    func start(
        locale requestedLocale: Locale = .current,
        contextualStrings: [String] = [],
        onTranscript: @escaping TranscriptHandler,
        onAudioLevel: @escaping AudioLevelHandler
    ) async throws {
        guard !isRecording else { return }

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
        if !contextualStrings.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = contextualStrings
            try await analyzer.setContext(context)
        }
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw DictationServiceError.missingAudioFormat
        }

        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.analyzer = analyzer
        self.transcriber = transcriber
        self.inputContinuation = continuation
        self.finalizedText = ""
        self.volatileText = ""

        resultTask = Task { [weak self] in
            for try await result in transcriber.results {
                guard let self else { return }
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                self.accept(text: text, isFinal: result.isFinal, handler: onTranscript)
            }
        }

        try await analyzer.start(inputSequence: stream)
        try startAudioEngine(
            analyzerFormat: analyzerFormat,
            continuation: continuation,
            onAudioLevel: onAudioLevel
        )
        isRecording = true
    }

    func stop() async throws -> String {
        try stopCapturing()
        return try await finalizeTranscription()
    }

    func stopCapturing() throws {
        guard isRecording else { throw DictationServiceError.notRecording }
        isRecording = false

        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine.stop()
        inputContinuation?.finish()
        inputContinuation = nil
    }

    func finalizeTranscription() async throws -> String {
        guard let analyzer else { throw DictationServiceError.notRecording }
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        try await resultTask?.value

        let text = combinedTranscript
        resultTask = nil
        self.analyzer = nil
        transcriber = nil
        converter = nil
        return text
    }

    func cancel() async {
        isRecording = false
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine.stop()
        inputContinuation?.finish()
        inputContinuation = nil
        await analyzer?.cancelAndFinishNow()
        resultTask?.cancel()
        resultTask = nil
        analyzer = nil
        transcriber = nil
        converter = nil
    }

    private var combinedTranscript: String {
        [finalizedText, volatileText]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func accept(text: String, isFinal: Bool, handler: TranscriptHandler) {
        if isFinal {
            if !text.isEmpty {
                finalizedText = [finalizedText, text].filter { !$0.isEmpty }.joined(separator: " ")
            }
            volatileText = ""
        } else {
            volatileText = text
        }
        handler(combinedTranscript)
    }

    private func startAudioEngine(
        analyzerFormat: AVAudioFormat,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        onAudioLevel: @escaping AudioLevelHandler
    ) throws {
        let inputNode = audioEngine.inputNode
        let microphoneFormat = inputNode.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: microphoneFormat, to: analyzerFormat) else {
            throw DictationServiceError.audioConversionFailed
        }
        self.converter = converter
        let levelSampler = AudioLevelSampler(handler: onAudioLevel)

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: microphoneFormat) { buffer, _ in
            levelSampler.consume(buffer)
            guard let converted = Self.convert(buffer, using: converter, to: analyzerFormat) else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }
        tapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()
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
