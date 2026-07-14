import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct LLMPrediction {
    var suggestions: [String] = []
    /// If the trailing text contains an obvious typo or wrong word, the model
    /// returns the corrected version of that trailing portion.
    var correctionTarget: String?
    var correctionReplacement: String?
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct TypingAssist {
    @Guide(description: "Up to 3 likely next words or short phrase continuations for the text, most likely first. Single words preferred, max 3 words each. Do not repeat words already typed.")
    var suggestions: [String]

    @Guide(description: "If the last sentence of the typed text contains an obvious typo, misspelling, or wrong word (like their/there), the exact substring that is wrong. Empty string if the text is fine.")
    var mistake: String

    @Guide(description: "The corrected replacement for the mistake. Empty string if the text is fine.")
    var correction: String
}

/// Wraps Apple's on-device foundation model. Inference runs in a system
/// process, so model weights don't count against the extension's memory cap.
@available(iOS 26.0, *)
final class LLMPredictor {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Whether the on-device model officially supports a language ("ro-RO" → false today).
    static func supportsLanguage(id: String) -> Bool {
        let code = String(id.prefix(2))
        return SystemLanguageModel.default.supportedLanguages.contains {
            $0.languageCode?.identifier == code
        }
    }

    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off. Enable it in Settings."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading. Try again soon."
        case .unavailable:
            return "The on-device model is unavailable right now."
        }
    }

    private var instructions: String
    private var warmSession: LanguageModelSession?

    init(languageNames: [String]) {
        let languages = languageNames.joined(separator: ", ")
        instructions = """
        You are the prediction engine inside a smartphone keyboard. The user types in: \(languages). \
        Detect which of these languages the text is in and respond in that same language. \
        You receive the text visible in the current text field, which may end mid-word or mid-sentence. \
        Predict what the user will type next, and spot obvious typos in the last sentence. \
        Suggestions must be natural continuations: if the text ends mid-word, complete that word; \
        otherwise suggest the next word or a short phrase. Never explain, never add punctuation-only suggestions.
        """
        prewarm()
    }

    func updateLanguages(_ languageNames: [String]) {
        let languages = languageNames.joined(separator: ", ")
        if !instructions.contains(languages) {
            instructions = instructions.replacingOccurrences(
                of: #"types in: [^.]+\."#,
                with: "types in: \(languages).",
                options: .regularExpression)
            warmSession = nil
            prewarm()
        }
    }

    func prewarm() {
        guard Self.isAvailable else { return }
        let session = LanguageModelSession(instructions: instructions)
        session.prewarm()
        warmSession = session
    }

    func predict(context: String) async throws -> LLMPrediction {
        guard Self.isAvailable else { return LLMPrediction() }

        // Sessions accumulate a transcript; use the prewarmed one once, then
        // replace it so every request is stateless.
        let session = warmSession ?? LanguageModelSession(instructions: instructions)
        warmSession = nil
        defer { prewarm() }

        let trimmedContext = String(context.suffix(400))
        let prompt = "Text in the field so far:\n\"\(trimmedContext)\""

        let options = GenerationOptions(temperature: 0.3)
        let response = try await session.respond(
            to: prompt,
            generating: TypingAssist.self,
            options: options
        )

        var result = LLMPrediction()
        result.suggestions = response.content.suggestions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count < 40 }

        let mistake = response.content.mistake.trimmingCharacters(in: .whitespacesAndNewlines)
        let correction = response.content.correction.trimmingCharacters(in: .whitespacesAndNewlines)
        if !mistake.isEmpty, !correction.isEmpty, mistake != correction,
           trimmedContext.contains(mistake) {
            result.correctionTarget = mistake
            result.correctionReplacement = correction
        }
        return result
    }
}
#endif
