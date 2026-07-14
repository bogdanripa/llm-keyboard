import UIKit

/// Horizontal popup shown above a key on long-press, offering accent variants.
/// The user slides to a variant and lifts to select it.
final class AccentPicker: UIView {
    private let options: [String]
    private var optionLabels: [UILabel] = []
    private(set) var selectedIndex = 0
    private let theme: KeyboardTheme

    static let optionWidth: CGFloat = 40
    static let height: CGFloat = 52

    init(options: [String], theme: KeyboardTheme) {
        self.options = options
        self.theme = theme
        super.init(frame: CGRect(x: 0, y: 0,
                                 width: CGFloat(options.count) * Self.optionWidth + 12,
                                 height: Self.height))
        backgroundColor = theme.isDark ? UIColor(white: 0.3, alpha: 1) : .white
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 6

        for (index, option) in options.enumerated() {
            let label = UILabel()
            label.text = option
            label.font = .systemFont(ofSize: 24, weight: .light)
            label.textColor = theme.keyText
            label.textAlignment = .center
            label.frame = CGRect(x: 6 + CGFloat(index) * Self.optionWidth, y: 4,
                                 width: Self.optionWidth, height: Self.height - 8)
            label.layer.cornerRadius = 8
            label.layer.masksToBounds = true
            addSubview(label)
            optionLabels.append(label)
        }
        highlight(index: 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    var selectedOption: String { options[selectedIndex] }

    /// Update the highlighted option from a touch location in this view's coordinates.
    func updateSelection(at point: CGPoint) {
        let index = Int((point.x - 6) / Self.optionWidth)
        highlight(index: max(0, min(options.count - 1, index)))
    }

    private func highlight(index: Int) {
        selectedIndex = index
        for (i, label) in optionLabels.enumerated() {
            label.backgroundColor = i == index ? theme.accentTint : .clear
            label.textColor = i == index ? .white : theme.keyText
        }
    }
}
