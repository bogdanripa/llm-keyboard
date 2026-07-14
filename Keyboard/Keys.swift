import UIKit

enum Key: Equatable {
    case character(String)
    case shift
    case backspace
    case space
    case newline          // return key
    case globe
    case numbers          // switch to number layer
    case letters          // switch to letter layer
    case symbols          // switch to symbol layer

    var isSpecial: Bool {
        if case .character = self { return false }
        return true
    }
}

enum ShiftState {
    case off, on, capsLock

    var isUppercased: Bool { self != .off }
}

enum KeyboardLayer {
    case letters, numbers, symbols
}

struct KeyboardLayout {
    /// Rows of keys; special keys are sized by `widthMultiplier`.
    let rows: [[Key]]

    static let letters = KeyboardLayout(rows: [
        "qwertyuiop".map { .character(String($0)) },
        "asdfghjkl".map { .character(String($0)) },
        [.shift] + "zxcvbnm".map { .character(String($0)) } + [.backspace],
        [.numbers, .globe, .space, .newline],
    ])

    static let numbers = KeyboardLayout(rows: [
        "1234567890".map { .character(String($0)) },
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""].map { .character($0) },
        [.symbols] + [".", ",", "?", "!", "'"].map { Key.character($0) } + [.backspace],
        [.letters, .globe, .space, .newline],
    ])

    static let symbols = KeyboardLayout(rows: [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map { .character($0) },
        ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"].map { .character($0) },
        [.numbers] + [".", ",", "?", "!", "'"].map { Key.character($0) } + [.backspace],
        [.letters, .globe, .space, .newline],
    ])

    static func layout(for layer: KeyboardLayer) -> KeyboardLayout {
        switch layer {
        case .letters: return .letters
        case .numbers: return .numbers
        case .symbols: return .symbols
        }
    }
}

enum KeyboardMetrics {
    static let rowHeight: CGFloat = 54
    static let suggestionBarHeight: CGFloat = 44
    static let keyGapX: CGFloat = 6
    static let keyGapY: CGFloat = 11
    static let sideInset: CGFloat = 3

    static var totalHeight: CGFloat { suggestionBarHeight + rowHeight * 4 + keyGapY }
}

/// Colors that adapt to the keyboard appearance (light/dark).
struct KeyboardTheme {
    let isDark: Bool

    var keyBackground: UIColor { isDark ? UIColor(white: 0.42, alpha: 1) : .white }
    var specialKeyBackground: UIColor { isDark ? UIColor(white: 0.26, alpha: 1) : UIColor(red: 0.68, green: 0.70, blue: 0.75, alpha: 1) }
    var keyText: UIColor { isDark ? .white : .black }
    var background: UIColor { .clear }
    var suggestionText: UIColor { isDark ? .white : .black }
    var suggestionHighlight: UIColor { isDark ? UIColor(white: 1, alpha: 0.14) : UIColor(white: 0, alpha: 0.08) }
    var accentTint: UIColor { UIColor(red: 0.35, green: 0.42, blue: 0.98, alpha: 1) }

    init(appearance: UIKeyboardAppearance) {
        isDark = appearance == .dark
    }

    init(traits: UITraitCollection, appearance: UIKeyboardAppearance) {
        if appearance == .dark {
            isDark = true
        } else if appearance == .light {
            isDark = false
        } else {
            isDark = traits.userInterfaceStyle == .dark
        }
    }
}
