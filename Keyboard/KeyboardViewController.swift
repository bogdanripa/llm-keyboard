import UIKit

final class KeyboardViewController: UIInputViewController {
    private var keyboardView: KeyboardView!
    private let engine = PredictionEngine()
    private var heightConstraint: NSLayoutConstraint?

    /// Last autocorrect we applied, so the user can revert it from the strip.
    private var lastAutocorrect: (original: String, corrected: String)?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardSettings.registerDefaults()

        let theme = KeyboardTheme(traits: traitCollection, appearance: textDocumentProxy.keyboardAppearance ?? .default)
        keyboardView = KeyboardView(theme: theme)
        keyboardView.delegate = self
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        engine.onSuggestions = { [weak self] suggestions in
            self?.showSuggestions(suggestions)
        }

        requestSupplementaryLexicon { [weak self] lexicon in
            DispatchQueue.main.async {
                self?.engine.setLexicon(lexicon)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        engine.reloadSettings()
        keyboardView.setAccentMap(KeyboardSettings.mergedAccents(for: KeyboardSettings.enabledLanguages))
        applyThemeFromContext()
        updateReturnKeyLabel()
        updateSpaceLabel()
        updateAutoShift()
        refreshPredictions()
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        if heightConstraint == nil {
            let constraint = view.heightAnchor.constraint(equalToConstant: KeyboardMetrics.totalHeight)
            constraint.priority = UILayoutPriority(999)
            constraint.isActive = true
            heightConstraint = constraint
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        applyThemeFromContext()
        updateReturnKeyLabel()
        updateAutoShift()
        refreshPredictions()
    }

    // MARK: - Context helpers

    private var contextBefore: String { textDocumentProxy.documentContextBeforeInput ?? "" }

    private var currentWord: String {
        guard let context = textDocumentProxy.documentContextBeforeInput, !context.isEmpty else { return "" }
        var word = ""
        for character in context.reversed() {
            if character.isLetter || character == "'" || character == "’" {
                word.insert(character, at: word.startIndex)
            } else {
                break
            }
        }
        return word
    }

    private func refreshPredictions() {
        engine.contextChanged(fullContext: contextBefore, currentWord: currentWord)
        updateSpaceLabel()
    }

    private func showSuggestions(_ suggestions: [Suggestion]) {
        var items = suggestions
        // Offer a revert right after an autocorrect.
        if let last = lastAutocorrect,
           contextBefore.hasSuffix(last.corrected + " ") || contextBefore.hasSuffix(last.corrected) {
            items.insert(Suggestion(
                display: "\u{201C}\(last.original)\u{201D}",
                action: .replaceTrailingText(target: last.corrected, replacement: last.original)), at: 0)
            items = Array(items.prefix(3))
        }
        keyboardView.suggestionBar.update(suggestions: items)
    }

    // MARK: - Appearance

    private func applyThemeFromContext() {
        let theme = KeyboardTheme(traits: traitCollection, appearance: textDocumentProxy.keyboardAppearance ?? .default)
        keyboardView.applyTheme(theme)
    }

    private func updateReturnKeyLabel() {
        let label: String
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: label = "go"
        case .search, .google, .yahoo: label = "search"
        case .send: label = "send"
        case .next: label = "next"
        case .done: label = "done"
        case .join: label = "join"
        case .emergencyCall: label = "call"
        case .route: label = "route"
        case .continue: label = "continue"
        default: label = "return"
        }
        keyboardView.setReturnKeyLabel(label)
    }

    private func updateSpaceLabel() {
        let name = engine.currentLanguage.autonym
        keyboardView.setSpaceLabel(engine.llmActive ? "✦ \(name)" : name)
    }

    // MARK: - Auto-capitalization

    private func updateAutoShift() {
        guard keyboardView.shiftState != .capsLock else { return }
        guard keyboardView.activeLayer == .letters else { return }
        let type = textDocumentProxy.autocapitalizationType ?? .sentences
        let context = contextBefore

        let shouldShift: Bool
        switch type {
        case .none: shouldShift = false
        case .allCharacters: shouldShift = true
        case .words: shouldShift = context.isEmpty || context.hasSuffix(" ") || context.hasSuffix("\n")
        default: // .sentences
            if context.isEmpty || context.hasSuffix("\n") {
                shouldShift = true
            } else {
                let trimmed = context.trimmingCharacters(in: .whitespaces)
                let lastMeaningful = trimmed.last
                shouldShift = context.hasSuffix(" ") && (lastMeaningful == "." || lastMeaningful == "!" || lastMeaningful == "?")
            }
        }
        keyboardView.setShiftState(shouldShift ? .on : .off)
    }

    // MARK: - Editing primitives

    private func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
    }

    private func deleteCharacters(_ count: Int) {
        for _ in 0..<count { textDocumentProxy.deleteBackward() }
    }

    /// Replace the word currently being typed with `replacement` + space.
    private func applyWordReplacement(_ replacement: String) {
        deleteCharacters(currentWord.count)
        insertText(replacement + " ")
    }

    /// Replace a trailing chunk of the document text (LLM fix / revert).
    private func applyTrailingReplacement(target: String, replacement: String) {
        let context = contextBefore
        guard let range = context.range(of: target, options: .backwards) else { return }
        let tail = String(context[range.upperBound...])
        // Only fix text near the end; bail out if the match is far away.
        guard tail.count <= 30 else { return }
        deleteCharacters(tail.count + target.count)
        insertText(replacement + tail)
    }

    // MARK: - Autocorrect on word boundary

    private func autocorrectIfNeeded() {
        let word = currentWord
        guard !word.isEmpty, let corrected = engine.autocorrection(for: word) else { return }
        deleteCharacters(word.count)
        insertText(corrected)
        lastAutocorrect = (original: word, corrected: corrected)
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardView(_ view: KeyboardView, didTap key: Key) {
        switch key {
        case .character(let value):
            let text = view.shiftState.isUppercased && view.activeLayer == .letters
                ? value.uppercased() : value
            // Word-boundary punctuation triggers autocorrect of the word before it.
            if [".", ",", "!", "?", ":", ";"].contains(value) {
                autocorrectIfNeeded()
            }
            insertText(text)
            if view.shiftState == .on && view.activeLayer == .letters {
                view.setShiftState(.off)
            }
        case .space:
            handleSpace()
        case .newline:
            autocorrectIfNeeded()
            insertText("\n")
        case .backspace:
            lastAutocorrect = nil
            textDocumentProxy.deleteBackward()
        case .shift:
            view.setShiftState(view.shiftState == .off ? .on : .off)
        case .numbers:
            view.setLayer(.numbers)
        case .letters:
            view.setLayer(.letters)
            updateAutoShift()
        case .symbols:
            view.setLayer(.symbols)
        case .globe:
            break // handled by keyboardViewDidTapGlobe
        }
        refreshAfterEdit(key: key)
    }

    private func handleSpace() {
        // Double-tap space → ". "
        let context = contextBefore
        if context.hasSuffix(" "), !context.hasSuffix("  "),
           let beforeSpace = context.dropLast().last,
           beforeSpace.isLetter || beforeSpace.isNumber {
            textDocumentProxy.deleteBackward()
            insertText(". ")
            return
        }
        autocorrectIfNeeded()
        insertText(" ")
    }

    private func refreshAfterEdit(key: Key) {
        updateAutoShift()
        refreshPredictions()
    }

    func keyboardView(_ view: KeyboardView, didPickAccent accent: String) {
        insertText(accent)
        if view.shiftState == .on {
            view.setShiftState(.off)
        }
        updateAutoShift()
        refreshPredictions()
    }

    func keyboardView(_ view: KeyboardView, didSelect suggestion: Suggestion) {
        switch suggestion.action {
        case .replaceCurrentWord(let word):
            applyWordReplacement(word)
        case .replaceTrailingText(let target, let replacement):
            applyTrailingReplacement(target: target, replacement: replacement)
            lastAutocorrect = nil
        }
        updateAutoShift()
        refreshPredictions()
    }

    func keyboardViewDidDoubleTapShift(_ view: KeyboardView) {
        view.setShiftState(.capsLock)
    }

    func keyboardViewBackspaceRepeatTick(_ view: KeyboardView) {
        textDocumentProxy.deleteBackward()
        refreshPredictions()
    }

    func keyboardViewNeedsInputModeSwitch(_ view: KeyboardView) -> Bool {
        needsInputModeSwitchKey
    }

    func keyboardViewDidTapGlobe(_ view: KeyboardView, from button: UIView, with event: UIEvent?) {
        handleInputModeList(from: button, with: event ?? UIEvent())
    }
}
