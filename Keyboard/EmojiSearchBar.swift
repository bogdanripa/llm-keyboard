import UIKit

/// Replaces the suggestion strip while emoji search is active: shows the query
/// being typed, a horizontally scrollable row of matching emoji, and a cancel button.
final class EmojiSearchBar: UIView {
    var onPick: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private let queryLabel = UILabel()
    private let scrollView = UIScrollView()
    private let resultsStack = UIStackView()
    private let cancelButton = UIButton(type: .system)
    private var theme: KeyboardTheme

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)

        queryLabel.font = .systemFont(ofSize: 15)
        addSubview(queryLabel)

        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)

        resultsStack.axis = .horizontal
        resultsStack.spacing = 2
        scrollView.addSubview(resultsStack)

        cancelButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        cancelButton.addTarget(self, action: #selector(tapCancel), for: .touchUpInside)
        addSubview(cancelButton)

        applyTheme(theme)
    }

    required init?(coder: NSCoder) { fatalError() }

    func applyTheme(_ theme: KeyboardTheme) {
        self.theme = theme
        queryLabel.textColor = theme.suggestionText
        cancelButton.tintColor = theme.suggestionText.withAlphaComponent(0.6)
    }

    func update(query: String, results: [String]) {
        queryLabel.text = query.isEmpty ? "Search…" : query
        queryLabel.textColor = query.isEmpty
            ? theme.suggestionText.withAlphaComponent(0.4) : theme.suggestionText

        resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for emoji in results {
            let button = UIButton(type: .system)
            button.setTitle(emoji, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 26)
            button.addAction(UIAction { [weak self] _ in self?.onPick?(emoji) }, for: .touchUpInside)
            button.widthAnchor.constraint(equalToConstant: 38).isActive = true
            resultsStack.addArrangedSubview(button)
        }
        setNeedsLayout()
        layoutIfNeeded()
        scrollView.setContentOffset(.zero, animated: false)
    }

    @objc private func tapCancel() { onCancel?() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let queryWidth: CGFloat = min(140, max(72, queryLabel.intrinsicContentSize.width + 16))
        queryLabel.frame = CGRect(x: 12, y: 0, width: queryWidth, height: bounds.height)
        cancelButton.frame = CGRect(x: bounds.width - 40, y: 0, width: 36, height: bounds.height)
        scrollView.frame = CGRect(x: queryWidth + 16, y: 0,
                                  width: bounds.width - queryWidth - 16 - 44, height: bounds.height)
        let stackWidth = resultsStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        resultsStack.frame = CGRect(x: 0, y: 0, width: stackWidth, height: bounds.height)
        scrollView.contentSize = CGSize(width: stackWidth, height: bounds.height)
    }
}
