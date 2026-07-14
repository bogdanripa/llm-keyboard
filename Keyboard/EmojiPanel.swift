import UIKit

protocol EmojiPanelDelegate: AnyObject {
    func emojiPanel(_ panel: EmojiPanel, didPick emoji: String)
    func emojiPanelDidTapABC(_ panel: EmojiPanel)
    func emojiPanelDidTapSearch(_ panel: EmojiPanel)
    func emojiPanelDidTapBackspace(_ panel: EmojiPanel)
}

/// Full-keyboard emoji picker: search field, category grid, tab bar.
final class EmojiPanel: UIView {
    weak var delegate: EmojiPanelDelegate?

    private let store = EmojiStore.shared
    private var theme: KeyboardTheme
    private var collectionView: UICollectionView!
    private let searchButton = UIButton(type: .system)
    private let abcButton = UIButton(type: .system)
    private let backspaceButton = UIButton(type: .system)
    private var tabButtons: [UIButton] = []
    private var sections: [(title: String, items: [String])] = []

    private static let tabIcons = ["🕘", "😀", "👋", "🐻", "🍔", "✈️", "⚽", "💡", "🔣", "🏁"]

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 40, height: 40)
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        layout.sectionInset = UIEdgeInsets(top: 4, left: 8, bottom: 8, right: 8)
        layout.headerReferenceSize = CGSize(width: 0, height: 24)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: "emoji")
        collectionView.register(EmojiSectionHeader.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "header")
        collectionView.dataSource = self
        collectionView.delegate = self
        addSubview(collectionView)

        var searchConfig = UIButton.Configuration.gray()
        searchConfig.image = UIImage(systemName: "magnifyingglass")
        searchConfig.title = "Search Emoji"
        searchConfig.imagePadding = 6
        searchConfig.baseForegroundColor = .secondaryLabel
        searchConfig.cornerStyle = .medium
        searchButton.configuration = searchConfig
        searchButton.addTarget(self, action: #selector(tapSearch), for: .touchUpInside)
        addSubview(searchButton)

        abcButton.setTitle("ABC", for: .normal)
        abcButton.titleLabel?.font = .systemFont(ofSize: 15)
        abcButton.addTarget(self, action: #selector(tapABC), for: .touchUpInside)
        addSubview(abcButton)

        backspaceButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        backspaceButton.addTarget(self, action: #selector(tapBackspace), for: .touchUpInside)
        addSubview(backspaceButton)

        for (index, icon) in Self.tabIcons.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(icon, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 18)
            button.tag = index
            button.addTarget(self, action: #selector(tapTab(_:)), for: .touchUpInside)
            addSubview(button)
            tabButtons.append(button)
        }

        applyTheme(theme)
        reloadData()
    }

    required init?(coder: NSCoder) { fatalError() }

    func applyTheme(_ theme: KeyboardTheme) {
        self.theme = theme
        abcButton.tintColor = theme.keyText
        backspaceButton.tintColor = theme.keyText
        tabButtons.forEach { $0.tintColor = theme.keyText }
    }

    /// Rebuild sections (recents may have changed since last shown).
    func reloadData() {
        sections = []
        let recents = store.recents
        if !recents.isEmpty {
            sections.append((title: "Frequently Used", items: recents))
        }
        for (index, name) in store.groups.enumerated() {
            sections.append((title: name, items: store.items(inGroup: index).map(\.emoji)))
        }
        collectionView.reloadData()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let searchHeight: CGFloat = 36
        let tabBarHeight: CGFloat = 40
        searchButton.frame = CGRect(x: 10, y: 6, width: bounds.width - 20, height: searchHeight)
        collectionView.frame = CGRect(x: 0, y: searchHeight + 10,
                                      width: bounds.width,
                                      height: bounds.height - searchHeight - 10 - tabBarHeight)

        let y = bounds.height - tabBarHeight
        abcButton.frame = CGRect(x: 4, y: y, width: 44, height: tabBarHeight)
        backspaceButton.frame = CGRect(x: bounds.width - 48, y: y, width: 44, height: tabBarHeight)
        let tabsWidth = bounds.width - 104
        let tabWidth = tabsWidth / CGFloat(tabButtons.count)
        for (index, button) in tabButtons.enumerated() {
            button.frame = CGRect(x: 52 + CGFloat(index) * tabWidth, y: y, width: tabWidth, height: tabBarHeight)
        }
    }

    // MARK: - Actions

    @objc private func tapSearch() { delegate?.emojiPanelDidTapSearch(self) }
    @objc private func tapABC() { delegate?.emojiPanelDidTapABC(self) }
    @objc private func tapBackspace() { delegate?.emojiPanelDidTapBackspace(self) }

    @objc private func tapTab(_ sender: UIButton) {
        let hasRecents = !store.recents.isEmpty
        var section = sender.tag
        if sender.tag == 0 {
            section = 0 // recents tab: top (falls back to first group when empty)
        } else {
            section = sender.tag - 1 + (hasRecents ? 1 : 0)
        }
        guard section < sections.count, !sections[section].items.isEmpty else { return }
        let path = IndexPath(item: 0, section: section)
        collectionView.scrollToItem(at: path, at: .top, animated: false)
    }
}

extension EmojiPanel: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "emoji", for: indexPath) as! EmojiCell
        cell.label.text = sections[indexPath.section].items[indexPath.item]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! EmojiSectionHeader
        header.label.text = sections[indexPath.section].title
        header.label.textColor = theme.suggestionText.withAlphaComponent(0.6)
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let emoji = sections[indexPath.section].items[indexPath.item]
        store.addRecent(emoji)
        delegate?.emojiPanel(self, didPick: emoji)
    }
}

private final class EmojiCell: UICollectionViewCell {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 30)
        label.textAlignment = .center
        contentView.addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }
}

private final class EmojiSectionHeader: UICollectionReusableView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 10, dy: 2)
    }
}
