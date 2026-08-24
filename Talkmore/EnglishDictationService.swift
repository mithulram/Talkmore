import Foundation
import Observation

enum EnglishRecognitionReadiness {
    case preparing
    case highAccuracy
    case appleFallback
}

@MainActor
@Observable
final class EnglishDictationService: DictationService {
    private let parakeet = ParakeetDictationService()
    private let apple = AppleDictationService()
    private var parakeetPreparation: Task<Bool, Never>?
    private var applePreparation: Task<Bool, Never>?
    private var lastParakeetPreparationFailure: Date?
    private var activeService: (any DictationService)?
    private var isFinalizing = false
    private(set) var readiness: EnglishRecognitionReadiness = .preparing

    var completedTranscript: String? { activeService?.completedTranscript }
    var hasFinalResultAfterCapture: Bool { activeService?.hasFinalResultAfterCapture ?? false }
    var engineName: String { activeService?.engineName ?? preferredEngineName }
    var isHighAccuracyReady: Bool { parakeet.isPrepared }
    var preferredEngineName: String {
        parakeet.isPrepared ? parakeet.engineName : apple.engineName
    }
    var statusDescription: String {
        switch readiness {
        case .preparing:
            "High-accuracy English model preparing in background"
        case .highAccuracy:
            "High-accuracy English · automatic"
        case .appleFallback:
            "English recognition · Apple fallback"
        }
    }

    func prime() {
        guard !parakeet.isPrepared, parakeetPreparation == nil else { return }
        if let lastParakeetPreparationFailure,
           Date().timeIntervalSince(lastParakeetPreparationFailure) < 60 {
            return
        }
        readiness = .preparing
        parakeetPreparation = Task { [weak self, parakeet] in
            do {
                try await parakeet.prepare(locale: Locale(identifier: "en_US"))
                self?.readiness = .highAccuracy
                self?.parakeetPreparation = nil
                self?.lastParakeetPreparationFailure = nil
                return true
            } catch {
                self?.readiness = .appleFallback
                self?.parakeetPreparation = nil
                self?.lastParakeetPreparationFailure = Date()
                return false
            }
        }
        guard applePreparation == nil else { return }
        applePreparation = Task { [weak self, apple] in
            defer { self?.applePreparation = nil }
            do {
                try await apple.prepare(locale: Locale(identifier: "en_US"))
                return true
            } catch {
                return false
            }
        }
    }

    func prepare(locale: Locale = Locale(identifier: "en_US")) async throws {
        prime()
        if parakeet.isPrepared { return }
        _ = await applePreparation?.value
    }

    func start(
        locale: Locale = Locale(identifier: "en_US"),
        contextualStrings: [String] = [],
        onTranscript: @escaping TranscriptHandler,
        onAudioLevel: @escaping AudioLevelHandler
    ) async throws {
        prime()
        while isFinalizing {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        if parakeet.isPrepared {
            do {
                activeService = parakeet
                try await parakeet.start(
                    locale: Locale(identifier: "en_US"),
                    contextualStrings: contextualStrings,
                    onTranscript: onTranscript,
                    onAudioLevel: onAudioLevel
                )
                return
            } catch {
                await parakeet.cancel()
                readiness = .appleFallback
            }
        }

        if applePreparation == nil { primeAppleFallback() }
        _ = await applePreparation?.value
        activeService = apple
        try await apple.start(
            locale: Locale(identifier: "en_US"),
            contextualStrings: contextualStrings,
            onTranscript: onTranscript,
            onAudioLevel: onAudioLevel
        )
    }

    func stopCapturing() throws {
        guard let activeService else { throw DictationServiceError.notRecording }
        try activeService.stopCapturing()
    }

    func finalizeTranscription() async throws -> String {
        guard let activeService else { throw DictationServiceError.notRecording }
        isFinalizing = true
        defer { isFinalizing = false }
        return try await activeService.finalizeTranscription()
    }

    func cancel() async {
        await activeService?.cancel()
        activeService = nil
    }

    private func primeAppleFallback() {
        applePreparation = Task { [weak self, apple] in
            defer { self?.applePreparation = nil }
            do {
                try await apple.prepare(locale: Locale(identifier: "en_US"))
                return true
            } catch {
                return false
            }
        }
    }
}
