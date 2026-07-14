import UIKit

protocol KeyButtonDelegate: AnyObject {
    func keyButtonDidTap(_ button: KeyButton)
    func keyButton(_ button: KeyButton, didLongPressWithAccents accents: [String])
    func keyButton(_ button: KeyButton, accentTouchMoved touch: UITouch)
    func keyButton(_ button: KeyButton, accentTouchEnded touch: UITouch)
    /// Returns true while the accent picker is on screen for this button.
    func keyButtonHasActiveAccentPicker(_ button: KeyButton) -> Bool
    func keyButtonDidBeginBackspaceRepeat(_ button: KeyButton)
    func keyButtonDidEndBackspaceRepeat(_ button: KeyButton)
    func keyButtonDidDoubleTapShift(_ button: KeyButton)
}

final class KeyButton: UIControl {
    let key: Key
    weak var delegate: KeyButtonDelegate?
    var accents: [String] = []

    private let label = UILabel()
    private let imageView = UIImageView()
    private var theme: KeyboardTheme
    private var longPressTimer: Timer?
    private var backspaceActive = false
    private var lastShiftTap: TimeInterval = 0

    init(key: Key, theme: KeyboardTheme) {
        self.key = key
        self.theme = theme
        super.init(frame: .zero)

        layer.cornerRadius = 6
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 0

        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        addSubview(label)

        imageView.contentMode = .center
        addSubview(imageView)

        applyTheme(theme)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
        imageView.frame = bounds
    }

    private var restingBackground: UIColor {
        key.isSpecial && key != .space ? theme.specialKeyBackground : theme.keyBackground
    }

    func applyTheme(_ theme: KeyboardTheme) {
        self.theme = theme
        backgroundColor = restingBackground
        label.textColor = theme.keyText
        imageView.tintColor = theme.keyText
    }

    private func updateAccessibility(title: String?) {
        isAccessibilityElement = true
        accessibilityTraits = [.keyboardKey]
        switch key {
        case .character(let value): accessibilityLabel = title ?? value
        case .shift: accessibilityLabel = "shift"
        case .backspace: accessibilityLabel = "delete"
        case .space: accessibilityLabel = "space"
        case .newline: accessibilityLabel = title ?? "return"
        case .globe: accessibilityLabel = "next keyboard"
        case .numbers: accessibilityLabel = "numbers"
        case .letters: accessibilityLabel = "letters"
        case .symbols: accessibilityLabel = "symbols"
        case .emoji: accessibilityLabel = "emoji"
        }
    }

    func configure(title: String?, systemImage: String?, fontSize: CGFloat = 23) {
        updateAccessibility(title: title)
        if let title {
            label.text = title
            label.font = .systemFont(ofSize: fontSize, weight: key.isSpecial ? .regular : .light)
            label.isHidden = false
            imageView.isHidden = true
        } else if let systemImage {
            imageView.image = UIImage(systemName: systemImage,
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular))
            imageView.isHidden = false
            label.isHidden = true
        }
    }

    /// Persistent highlight, used for the shift key's active states.
    func setActive(_ active: Bool) {
        backgroundColor = active ? theme.keyBackground : restingBackground
        if key == .shift {
            imageView.tintColor = theme.keyText
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        alpha = 0.55
        switch key {
        case .backspace:
            backspaceActive = true
            delegate?.keyButtonDidTap(self)
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                guard let self, self.backspaceActive else { return }
                self.delegate?.keyButtonDidBeginBackspaceRepeat(self)
            }
        case .character:
            if !accents.isEmpty {
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.delegate?.keyButton(self, didLongPressWithAccents: self.accents)
                }
            }
        default:
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        if delegate?.keyButtonHasActiveAccentPicker(self) == true {
            delegate?.keyButton(self, accentTouchMoved: touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        alpha = 1
        longPressTimer?.invalidate()
        longPressTimer = nil

        switch key {
        case .backspace:
            backspaceActive = false
            delegate?.keyButtonDidEndBackspaceRepeat(self)
        case .shift:
            let now = CACurrentMediaTime()
            if now - lastShiftTap < 0.3 {
                delegate?.keyButtonDidDoubleTapShift(self)
            } else {
                delegate?.keyButtonDidTap(self)
            }
            lastShiftTap = now
        case .character:
            if delegate?.keyButtonHasActiveAccentPicker(self) == true, let touch = touches.first {
                delegate?.keyButton(self, accentTouchEnded: touch)
            } else {
                delegate?.keyButtonDidTap(self)
            }
        default:
            delegate?.keyButtonDidTap(self)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        alpha = 1
        longPressTimer?.invalidate()
        longPressTimer = nil
        switch key {
        case .backspace:
            backspaceActive = false
            delegate?.keyButtonDidEndBackspaceRepeat(self)
        case .character:
            if delegate?.keyButtonHasActiveAccentPicker(self) == true, let touch = touches.first {
                delegate?.keyButton(self, accentTouchEnded: touch)
            }
        default:
            break
        }
    }
}
