import UIKit
import NaturalLanguage

/// Two-tier prediction:
///  - Tier 1 (instant, every keystroke): UITextChecker word completions and
///    user-lexicon matches in the detected language.
///  - Tier 2 (debounced ~350 ms): Apple's on-device foundation model reads the
///    whole visible context and produces next-word/phrase predictions plus a
///    contextual typo fix. Falls back silently when unavailable.
@MainActor
final class PredictionEngine {
    var onSuggestions: (([Suggestion]) -> Void)?

    private let checker = UITextChecker()
    private let recognizer = NLLanguageRecognizer()
    private var lexicon: UILexicon?
    private var languages: [KeyboardLanguage] = KeyboardSettings.enabledLanguages
    private(set) var currentLanguage: KeyboardLanguage = KeyboardSettings.enabledLanguages[0]

    private var debounceTask: Task<Void, Never>?
    private var llmBusy = false
    private var pendingContext: String?
    private var latestRequestID = 0

    private var _llmPredictor: AnyObject?
    @available(iOS 26.0, *)
    private var llmPredictor: LLMPredictor? {
        get { _llmPredictor as? LLMPredictor }
        set { _llmPredictor = newValue }
    }

    var llmActive: Bool {
        if #available(iOS 26.0, *) {
            return KeyboardSettings.llmEnabled && LLMPredictor.isAvailable
        }
        return false
    }

    /// LLM predictions only run for languages the on-device model supports;
    /// others (e.g. Romanian) keep tier-1 predictions and autocorrect.
    var llmActiveForCurrentLanguage: Bool {
        if #available(iOS 26.0, *) {
            return llmActive && LLMPredictor.supportsLanguage(id: currentLanguage.id)
        }
        return false
    }

    init() {
        reloadSettings()
    }

    func reloadSettings() {
        languages = KeyboardSettings.enabledLanguages
        if !languages.contains(currentLanguage) {
            currentLanguage = languages[0]
        }
        if #available(iOS 26.0, *), KeyboardSettings.llmEnabled, LLMPredictor.isAvailable {
            if let predictor = llmPredictor {
                predictor.updateLanguages(languages.map(\.name))
            } else {
                llmPredictor = LLMPredictor(languageNames: languages.map(\.name))
            }
        }
    }

    func setLexicon(_ lexicon: UILexicon) {
        self.lexicon = lexicon
    }

    // MARK: - Language detection

    /// Detect which enabled language the user is typing, from recent context.
    func detectLanguage(context: String) {
        guard languages.count > 1 else {
            currentLanguage = languages[0]
            return
        }
        let sample = String(context.suffix(200))
        guard sample.count >= 8 else { return }
        recognizer.reset()
        recognizer.languageConstraints = languages.compactMap {
            NLLanguage($0.id.prefix(2).description)
        }
        recognizer.processString(sample)
        if let dominant = recognizer.dominantLanguage,
           let match = languages.first(where: { $0.id.hasPrefix(dominant.rawValue) }) {
            currentLanguage = match
        }
    }

    // MARK: - Main entry point

    /// Called on every keystroke / context change.
    func contextChanged(fullContext: String, currentWord: String) {
        detectLanguage(context: fullContext)

        // Tier 1: instant suggestions.
        let instant = tier1Suggestions(currentWord: currentWord)
        onSuggestions?(instant)

        // Tier 2: debounced LLM pass over the whole context.
        debounceTask?.cancel()
        guard llmActiveForCurrentLanguage,
              fullContext.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return }
        latestRequestID += 1
        let requestID = latestRequestID
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.runLLM(context: fullContext, currentWord: currentWord, requestID: requestID)
        }
    }

    // MARK: - Tier 1

    private func tier1Suggestions(currentWord: String) -> [Suggestion] {
        guard !currentWord.isEmpty else { return [] }
        var words: [String] = []

        // If the word-so-far is already misspelled, lead with the best fix
        // ("Helo" → "Hello") — completions alone would only offer "Helot(s)".
        if currentWord.count >= 3, let guess = spellingFix(for: currentWord) {
            words.append(guess)
        }

        // User lexicon (contact names, text replacements) first.
        if let lexicon {
            for entry in lexicon.entries
            where entry.userInput.lowercased().hasPrefix(currentWord.lowercased()) {
                words.append(entry.documentText)
                if words.count >= 2 { break }
            }
        }

        let nsWord = currentWord as NSString
        let range = NSRange(location: 0, length: nsWord.length)
        if let completions = checker.completions(
            forPartialWordRange: range, in: currentWord,
            language: currentLanguage.spellCheckerLanguage) {
            for completion in completions where !words.contains(completion) {
                words.append(completion)
                if words.count >= 3 { break }
            }
        }

        return words.prefix(3).map {
            Suggestion(display: $0, action: .replaceCurrentWord($0))
        }
    }

    // MARK: - Tier 2

    @available(iOS 17.0, *)
    private func runLLM(context: String, currentWord: String, requestID: Int) async {
        guard #available(iOS 26.0, *), let predictor = llmPredictor else { return }
        if llmBusy {
            pendingContext = context
            return
        }
        llmBusy = true
        defer {
            llmBusy = false
            // If more typing happened while the model was busy, run once more.
            if let pending = pendingContext {
                pendingContext = nil
                if pending != context {
                    contextChanged(fullContext: pending, currentWord: "")
                }
            }
        }

        guard let prediction = try? await predictor.predict(context: context) else { return }
        guard requestID == latestRequestID else { return } // stale — user kept typing

        var suggestions: [Suggestion] = []
        if let target = prediction.correctionTarget,
           let replacement = prediction.correctionReplacement {
            suggestions.append(Suggestion(
                display: replacement,
                action: .replaceTrailingText(target: target, replacement: replacement),
                isCorrection: true))
        }
        for word in prediction.suggestions where suggestions.count < 3 {
            // Mid-word: LLM should complete the current word; make sure the
            // suggestion actually extends it, otherwise treat as next word.
            if !currentWord.isEmpty,
               !word.lowercased().hasPrefix(currentWord.lowercased()) {
                continue
            }
            suggestions.append(Suggestion(display: word, action: .replaceCurrentWord(word)))
        }
        // Backfill with tier-1 completions if the LLM returned little.
        if suggestions.count < 3 {
            for extra in tier1Suggestions(currentWord: currentWord)
            where !suggestions.contains(where: { $0.display == extra.display }) {
                suggestions.append(extra)
                if suggestions.count >= 3 { break }
            }
        }
        if !suggestions.isEmpty {
            onSuggestions?(suggestions)
        }
    }

    // MARK: - Autocorrect (applied on space/punctuation)

    /// Dictionary-level autocorrect for a just-completed word.
    func autocorrection(for word: String) -> String? {
        guard KeyboardSettings.autocorrectEnabled else { return nil }
        return spellingFix(for: word)
    }

    /// Best spelling fix for a misspelled word, or nil if the word is fine
    /// or no trustworthy fix exists.
    private func spellingFix(for word: String) -> String? {
        guard word.count >= 2,
              word.rangeOfCharacter(from: .letters) != nil,
              word.rangeOfCharacter(from: .decimalDigits) == nil else { return nil }

        let language = currentLanguage.spellCheckerLanguage
        let nsWord = word as NSString
        let fullRange = NSRange(location: 0, length: nsWord.length)
        let misspelled = checker.rangeOfMisspelledWord(
            in: word, range: fullRange, startingAt: 0, wrap: false, language: language)
        guard misspelled.location != NSNotFound else { return nil }

        guard let guesses = checker.guesses(forWordRange: fullRange, in: word, language: language),
              !guesses.isEmpty else { return nil }

        // Near-miss candidates only; anything drastic isn't worth auto-applying.
        let plausible = guesses.filter {
            abs($0.count - word.count) <= 2 && $0.lowercased() != word.lowercased() && !$0.contains(" ")
        }
        // Prefer fixes where the user typed only correct letters and merely
        // missed some ("Helo" is a subsequence of "Hello" but not of "Help").
        let best = plausible.first { Self.isSubsequence(word.lowercased(), of: $0.lowercased()) }
            ?? plausible.first
        guard let best else { return nil }

        // Preserve leading capitalization.
        if let first = word.first, first.isUppercase, let bestFirst = best.first {
            return String(bestFirst).uppercased() + best.dropFirst()
        }
        return best
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var iterator = haystack.makeIterator()
        outer: for character in needle {
            while let candidate = iterator.next() {
                if candidate == character { continue outer }
            }
            return false
        }
        return true
    }
}
