@preconcurrency import AVFoundation
import Accelerate
import FluidAudio

private final class ParakeetAudioLevelSampler: @unchecked Sendable {
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

enum ParakeetDictationError: LocalizedError {
    case unsupportedHardware
    case notPrepared
    case notRecording
    case audioCopyFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedHardware:
            "The high-accuracy English model requires Apple silicon."
        case .notPrepared:
            "The high-accuracy English model is still preparing."
        case .notRecording:
            "No recording is currently active."
        case .audioCopyFailed:
            "Talkmore could not preserve an incoming microphone buffer."
        }
    }
}

@MainActor
final class ParakeetDictationService: DictationService {
    typealias TranscriptHandler = DictationService.TranscriptHandler
    typealias AudioLevelHandler = DictationService.AudioLevelHandler

    private let audioEngine = AVAudioEngine()
    private let manager: any StreamingAsrManager
    private var inputContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var processingTask: Task<Void, Error>?
    private var audioLevelHandler: AudioLevelHandler?
    private var isRecording = false
    private var tapInstalled = false

    private(set) var isPrepared = false
    private(set) var completedTranscript: String?
    private(set) var hasFinalResultAfterCapture = false
    let engineName = "Parakeet Unified English · 320 ms"

    init() {
        manager = StreamingModelVariant.parakeetUnified320ms.createManager()
    }

    func prepare(locale: Locale = Locale(identifier: "en_US")) async throws {
#if arch(arm64)
        guard !isPrepared else { return }
        try await manager.loadModels()
        isPrepared = true
#else
        throw ParakeetDictationError.unsupportedHardware
#endif
    }

    func start(
        locale: Locale = Locale(identifier: "en_US"),
        contextualStrings: [String] = [],
        onTranscript: @escaping TranscriptHandler,
        onAudioLevel: @escaping AudioLevelHandler
    ) async throws {
        guard !isRecording else { return }
        guard isPrepared else { throw ParakeetDictationError.notPrepared }

        try await manager.reset()
        await manager.setPartialTranscriptCallback { transcript in
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { @MainActor in onTranscript(trimmed) }
        }

        completedTranscript = nil
        hasFinalResultAfterCapture = false
        audioLevelHandler = onAudioLevel

        let (stream, continuation) = AsyncStream.makeStream(of: AVAudioPCMBuffer.self)
        inputContinuation = continuation
        processingTask = Task { [manager] in
            for await buffer in stream {
                try await manager.appendAudio(buffer)
                try await manager.processBufferedAudio()
            }
        }

        try configureAudioEngine(onAudioLevel: onAudioLevel, continuation: continuation)
        try audioEngine.start()
        isRecording = true
    }

    func stopCapturing() throws {
        guard isRecording else { throw ParakeetDictationError.notRecording }
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
        try await processingTask?.value
        processingTask = nil
        let text = try await manager.finish().trimmingCharacters(in: .whitespacesAndNewlines)
        completedTranscript = text
        hasFinalResultAfterCapture = true
        audioLevelHandler = nil
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
        processingTask?.cancel()
        processingTask = nil
        try? await manager.reset()
        completedTranscript = nil
        hasFinalResultAfterCapture = false
        audioLevelHandler = nil
    }

    private func configureAudioEngine(
        onAudioLevel: @escaping AudioLevelHandler,
        continuation: AsyncStream<AVAudioPCMBuffer>.Continuation
    ) throws {
        let inputNode = audioEngine.inputNode
        let microphoneFormat = inputNode.outputFormat(forBus: 0)
        let levelSampler = ParakeetAudioLevelSampler(handler: onAudioLevel)

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: microphoneFormat) { buffer, _ in
            levelSampler.consume(buffer)
            guard let copied = Self.copy(buffer) else { return }
            continuation.yield(copied)
        }
        tapInstalled = true
        audioEngine.prepare()
    }

    private static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let destination = AVAudioPCMBuffer(
            pcmFormat: source.format,
            frameCapacity: source.frameLength
        ) else { return nil }
        destination.frameLength = source.frameLength

        let sourceBuffers = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(destination.mutableAudioBufferList)
        guard sourceBuffers.count == destinationBuffers.count else { return nil }

        for index in sourceBuffers.indices {
            guard let sourceData = sourceBuffers[index].mData,
                  let destinationData = destinationBuffers[index].mData else { return nil }
            let byteCount = min(
                Int(sourceBuffers[index].mDataByteSize),
                Int(destinationBuffers[index].mDataByteSize)
            )
            memcpy(destinationData, sourceData, byteCount)
            destinationBuffers[index].mDataByteSize = UInt32(byteCount)
        }
        return destination
    }
}
