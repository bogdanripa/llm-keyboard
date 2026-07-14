import UIKit

struct Suggestion: Equatable {
    enum Action: Equatable {
        /// Replace the word currently being typed (or insert at cursor if none).
        case replaceCurrentWord(String)
        /// Replace a trailing chunk of the document text (LLM contextual fix).
        case replaceTrailingText(target: String, replacement: String)
    }

    let display: String
    let action: Action
    var isCorrection: Bool = false
}

final class SuggestionBar: UIView {
    var onSelect: ((Suggestion) -> Void)?

    private var suggestions: [Suggestion] = []
    private var buttons: [UIButton] = []
    private var separators: [UIView] = []
    private var theme: KeyboardTheme

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    func applyTheme(_ theme: KeyboardTheme) {
        self.theme = theme
        update(suggestions: suggestions)
    }

    func update(suggestions: [Suggestion]) {
        self.suggestions = suggestions
        buttons.forEach { $0.removeFromSuperview() }
        separators.forEach { $0.removeFromSuperview() }
        buttons = []
        separators = []

        for (index, suggestion) in suggestions.prefix(3).enumerated() {
            let button = UIButton(type: .system)
            var config = UIButton.Configuration.plain()
            let title = suggestion.isCorrection ? "✦ " + suggestion.display : suggestion.display
            var attributes = AttributeContainer()
            attributes.font = UIFont.systemFont(ofSize: 16, weight: suggestion.isCorrection ? .semibold : .regular)
            attributes.foregroundColor = suggestion.isCorrection ? theme.accentTint : theme.suggestionText
            config.attributedTitle = AttributedString(title, attributes: attributes)
            config.titleLineBreakMode = .byTruncatingTail
            config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
            button.configuration = config
            button.tag = index
            button.addTarget(self, action: #selector(didTapSuggestion(_:)), for: .touchUpInside)
            addSubview(button)
            buttons.append(button)

            if index > 0 {
                let separator = UIView()
                separator.backgroundColor = theme.suggestionText.withAlphaComponent(0.2)
                addSubview(separator)
                separators.append(separator)
            }
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    @objc private func didTapSuggestion(_ sender: UIButton) {
        guard sender.tag < suggestions.count else { return }
        onSelect?(suggestions[sender.tag])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !buttons.isEmpty else { return }

        // A correction suggestion may be long: give it up to 60% of the bar.
        let count = buttons.count
        var widths = [CGFloat](repeating: bounds.width / CGFloat(count), count: count)
        if let correctionIndex = suggestions.prefix(3).firstIndex(where: { $0.isCorrection }), count > 1 {
            let wide = bounds.width * 0.6
            let rest = (bounds.width - wide) / CGFloat(count - 1)
            for i in 0..<count { widths[i] = i == correctionIndex ? wide : rest }
        }

        var x: CGFloat = 0
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: x, y: 0, width: widths[index], height: bounds.height)
            x += widths[index]
            if index < separators.count {
                separators[index].frame = CGRect(x: x - 0.5, y: bounds.height * 0.25,
                                                 width: 1, height: bounds.height * 0.5)
            }
        }
    }
}
