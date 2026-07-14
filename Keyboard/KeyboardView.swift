import UIKit

protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didTap key: Key)
    func keyboardView(_ view: KeyboardView, didPickAccent accent: String)
    func keyboardView(_ view: KeyboardView, didSelect suggestion: Suggestion)
    func keyboardViewDidDoubleTapShift(_ view: KeyboardView)
    func keyboardViewBackspaceRepeatTick(_ view: KeyboardView)
    func keyboardViewNeedsInputModeSwitch(_ view: KeyboardView) -> Bool
    func keyboardViewDidTapGlobe(_ view: KeyboardView, from button: UIView, with event: UIEvent?)
}

final class KeyboardView: UIView, UIInputViewAudioFeedback {
    weak var delegate: KeyboardViewDelegate?

    var enableInputClicksWhenVisible: Bool { true }

    private(set) var activeLayer: KeyboardLayer = .letters
    private(set) var shiftState: ShiftState = .on
    private var theme: KeyboardTheme
    private var accentMap: [String: [String]] = [:]
    private var spaceLabel = "LLM Keys"
    private var returnLabel = "return"

    let suggestionBar: SuggestionBar
    private var keyButtons: [KeyButton] = []
    private var accentPicker: AccentPicker?
    private var accentSourceButton: KeyButton?
    private var backspaceTimer: Timer?

    init(theme: KeyboardTheme) {
        self.theme = theme
        suggestionBar = SuggestionBar(theme: theme)
        super.init(frame: .zero)
        addSubview(suggestionBar)
        suggestionBar.onSelect = { [weak self] suggestion in
            guard let self else { return }
            self.delegate?.keyboardView(self, didSelect: suggestion)
        }
        rebuildKeys()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    func applyTheme(_ theme: KeyboardTheme) {
        self.theme = theme
        suggestionBar.applyTheme(theme)
        keyButtons.forEach { $0.applyTheme(theme) }
        refreshKeyCaps()
    }

    func setAccentMap(_ map: [String: [String]]) {
        accentMap = map
        for button in keyButtons {
            if case .character(let value) = button.key {
                button.accents = map[value.lowercased()] ?? []
            }
        }
    }

    func setLayer(_ layer: KeyboardLayer) {
        guard layer != activeLayer else { return }
        activeLayer = layer
        rebuildKeys()
    }

    func setShiftState(_ state: ShiftState) {
        shiftState = state
        refreshKeyCaps()
    }

    func setSpaceLabel(_ label: String) {
        spaceLabel = label
        refreshKeyCaps()
    }

    func setReturnKeyLabel(_ label: String) {
        returnLabel = label
        refreshKeyCaps()
    }

    // MARK: - Key construction

    private func rebuildKeys() {
        keyButtons.forEach { $0.removeFromSuperview() }
        keyButtons = []

        let layout = KeyboardLayout.layout(for: activeLayer)
        let needsGlobe = delegate?.keyboardViewNeedsInputModeSwitch(self) ?? true

        for row in layout.rows {
            for key in row {
                if key == .globe && !needsGlobe { continue }
                let button = KeyButton(key: key, theme: theme)
                button.delegate = self
                if case .character(let value) = key {
                    button.accents = accentMap[value.lowercased()] ?? []
                }
                if key == .globe {
                    // The globe key must call handleInputModeList on touch events.
                    button.addTarget(self, action: #selector(globeTouched(_:forEvent:)), for: .allTouchEvents)
                }
                addSubview(button)
                keyButtons.append(button)
            }
        }
        refreshKeyCaps()
        setNeedsLayout()
    }

    @objc private func globeTouched(_ sender: UIButton, forEvent event: UIEvent?) {
        delegate?.keyboardViewDidTapGlobe(self, from: sender, with: event)
    }

    private func refreshKeyCaps() {
        for button in keyButtons {
            switch button.key {
            case .character(let value):
                let display = shiftState.isUppercased && activeLayer == .letters ? value.uppercased() : value
                button.configure(title: display, systemImage: nil)
            case .shift:
                let symbol: String
                switch shiftState {
                case .off: symbol = "shift"
                case .on: symbol = "shift.fill"
                case .capsLock: symbol = "capslock.fill"
                }
                button.configure(title: nil, systemImage: symbol)
                button.setActive(shiftState != .off)
            case .backspace:
                button.configure(title: nil, systemImage: "delete.left")
            case .space:
                button.configure(title: spaceLabel, systemImage: nil, fontSize: 15)
            case .newline:
                button.configure(title: returnLabel, systemImage: nil, fontSize: 15)
            case .globe:
                button.configure(title: nil, systemImage: "globe")
            case .numbers:
                button.configure(title: "123", systemImage: nil, fontSize: 15)
            case .letters:
                button.configure(title: "ABC", systemImage: nil, fontSize: 15)
            case .symbols:
                button.configure(title: "#+=", systemImage: nil, fontSize: 15)
            }
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let width = bounds.width
        suggestionBar.frame = CGRect(x: 0, y: 0, width: width, height: KeyboardMetrics.suggestionBarHeight)

        let layout = KeyboardLayout.layout(for: activeLayer)
        let side = KeyboardMetrics.sideInset
        let gapX = KeyboardMetrics.keyGapX
        let rowHeight = KeyboardMetrics.rowHeight
        let keyHeight = rowHeight - KeyboardMetrics.keyGapY
        let baseKeyWidth = (width - 2 * side - 9 * gapX) / 10

        var buttonIndex = 0
        let needsGlobe = delegate?.keyboardViewNeedsInputModeSwitch(self) ?? true

        for (rowIndex, row) in layout.rows.enumerated() {
            let visibleRow = row.filter { $0 != .globe || needsGlobe }
            let y = KeyboardMetrics.suggestionBarHeight + CGFloat(rowIndex) * rowHeight + KeyboardMetrics.keyGapY / 2

            let widths = rowWidths(for: visibleRow, rowIndex: rowIndex,
                                   totalWidth: width, baseKeyWidth: baseKeyWidth)
            let rowContentWidth = widths.reduce(0, +) + gapX * CGFloat(visibleRow.count - 1)
            var x = (width - rowContentWidth) / 2

            for keyWidth in widths {
                guard buttonIndex < keyButtons.count else { break }
                keyButtons[buttonIndex].frame = CGRect(x: x, y: y, width: keyWidth, height: keyHeight)
                x += keyWidth + gapX
                buttonIndex += 1
            }
        }
    }

    private func rowWidths(for row: [Key], rowIndex: Int,
                           totalWidth: CGFloat, baseKeyWidth: CGFloat) -> [CGFloat] {
        let side = KeyboardMetrics.sideInset
        let gapX = KeyboardMetrics.keyGapX
        let available = totalWidth - 2 * side - gapX * CGFloat(row.count - 1)

        // Bottom row: fixed special keys, space takes the remainder.
        if rowIndex == 3 {
            let numbersWidth = baseKeyWidth * 1.3
            let globeWidth = baseKeyWidth * 1.2
            let returnWidth = baseKeyWidth * 2.3
            return row.map { key in
                switch key {
                case .numbers, .letters: return numbersWidth
                case .globe: return globeWidth
                case .newline: return returnWidth
                case .space:
                    let fixed = row.reduce(CGFloat(0)) { sum, k in
                        switch k {
                        case .numbers, .letters: return sum + numbersWidth
                        case .globe: return sum + globeWidth
                        case .newline: return sum + returnWidth
                        default: return sum
                        }
                    }
                    return available - fixed
                default: return baseKeyWidth
                }
            }
        }

        // Third row: side special keys (shift/backspace or layer switch/backspace).
        if rowIndex == 2 {
            let charCount = CGFloat(row.filter { !$0.isSpecial }.count)
            let specialCount = CGFloat(row.filter { $0.isSpecial }.count)
            if charCount == 7 {
                // Letter layer: letters keep base width, specials absorb the rest.
                let specialWidth = (available - 7 * baseKeyWidth) / max(specialCount, 1)
                return row.map { $0.isSpecial ? specialWidth : baseKeyWidth }
            } else {
                // Number/symbol layer: 5 wide character keys.
                let specialWidth = baseKeyWidth * 1.35
                let charWidth = (available - specialCount * specialWidth) / max(charCount, 1)
                return row.map { $0.isSpecial ? specialWidth : charWidth }
            }
        }

        // Rows 0 and 1: uniform base-width keys, centered.
        return row.map { _ in baseKeyWidth }
    }

    // MARK: - Accent picker

    private func showAccentPicker(for button: KeyButton, options: [String]) {
        dismissAccentPicker()
        let picker = AccentPicker(options: options, theme: theme)
        var origin = CGPoint(x: button.frame.midX - picker.bounds.width / 2,
                             y: button.frame.minY - AccentPicker.height - 6)
        origin.x = max(4, min(bounds.width - picker.bounds.width - 4, origin.x))
        origin.y = max(2, origin.y)
        picker.frame.origin = origin
        addSubview(picker)
        accentPicker = picker
        accentSourceButton = button
    }

    private func dismissAccentPicker() {
        accentPicker?.removeFromSuperview()
        accentPicker = nil
        accentSourceButton = nil
    }
}

// MARK: - KeyButtonDelegate

extension KeyboardView: KeyButtonDelegate {
    func keyButtonDidTap(_ button: KeyButton) {
        if button.key == .globe { return } // handled via globeTouched
        UIDevice.current.playInputClick()
        delegate?.keyboardView(self, didTap: button.key)
    }

    func keyButton(_ button: KeyButton, didLongPressWithAccents accents: [String]) {
        guard case .character(let value) = button.key else { return }
        let display = shiftState.isUppercased && activeLayer == .letters
            ? [value.uppercased()] + accents.map { $0.uppercased() }
            : [value] + accents
        showAccentPicker(for: button, options: display)
    }

    func keyButton(_ button: KeyButton, accentTouchMoved touch: UITouch) {
        guard let picker = accentPicker else { return }
        picker.updateSelection(at: touch.location(in: picker))
    }

    func keyButton(_ button: KeyButton, accentTouchEnded touch: UITouch) {
        guard let picker = accentPicker else { return }
        let accent = picker.selectedOption
        dismissAccentPicker()
        UIDevice.current.playInputClick()
        delegate?.keyboardView(self, didPickAccent: accent)
    }

    func keyButtonHasActiveAccentPicker(_ button: KeyButton) -> Bool {
        accentPicker != nil && accentSourceButton === button
    }

    func keyButtonDidBeginBackspaceRepeat(_ button: KeyButton) {
        backspaceTimer?.invalidate()
        backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.delegate?.keyboardViewBackspaceRepeatTick(self)
        }
    }

    func keyButtonDidEndBackspaceRepeat(_ button: KeyButton) {
        backspaceTimer?.invalidate()
        backspaceTimer = nil
    }

    func keyButtonDidDoubleTapShift(_ button: KeyButton) {
        UIDevice.current.playInputClick()
        delegate?.keyboardViewDidDoubleTapShift(self)
    }
}
