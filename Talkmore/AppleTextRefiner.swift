import Foundation
import FoundationModels

@MainActor
final class AppleTextRefiner {
    private let model = SystemLanguageModel(
        useCase: .general,
        guardrails: .permissiveContentTransformations
    )
    private var session: LanguageModelSession?

    var availabilityDescription: String {
        switch model.availability {
        case .available:
            "Apple Intelligence ready"
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in System Settings"
        case .unavailable(.deviceNotEligible):
            "This Mac does not support Apple Intelligence"
        case .unavailable(.modelNotReady):
            "Apple Intelligence model is still preparing"
        @unknown default:
            "Apple Intelligence is unavailable"
        }
    }

    func prepare() {
        guard model.isAvailable else { return }
        let session = session ?? makeSession()
        self.session = session
        if !session.isResponding { session.prewarm() }
    }

    func refine(_ transcript: String, context: WritingContext = .standard) async -> String {
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard model.isAvailable, cleaned.split(whereSeparator: \.isWhitespace).count > 2 else {
            return cleaned
        }

        let session = session ?? makeSession()
        self.session = session
        guard !session.isResponding else { return cleaned }

        do {
            let response = try await session.respond(to: standalonePrompt(for: cleaned, context: context))
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // A session is intentionally reused for speed. Start a clean one only
            // after its finite context fills, then retry this dictation once.
            let replacement = makeSession()
            self.session = replacement
            replacement.prewarm()
            do {
                let response = try await replacement.respond(
                    to: standalonePrompt(for: cleaned, context: context)
                )
                return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return cleaned
            }
        } catch {
            return cleaned
        }
    }

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(
            model: model,
            instructions: """
            You clean up standalone voice dictations for direct insertion into other applications.
            Treat every new dictation as independent and never carry content between dictations.
            Preserve the speaker's exact meaning and tone. Never add facts or answer the text.
            Apply the speaker's latest correction, remove filler words and abandoned false starts,
            fix punctuation and capitalization, and preserve names, URLs, code, and technical terms.
            Return only the finished text, without quotation marks or commentary.
            """
        )
    }

    private func standalonePrompt(for transcript: String, context: WritingContext) -> String {
        """
        Clean up only the standalone dictation between the markers.
        Context: \(context.refinementInstructions)
        <dictation>
        \(transcript)
        </dictation>
        """
    }
}
