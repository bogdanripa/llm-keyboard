import Foundation

/// Emoji grid data (Unicode emoji-test order/groups) plus multilingual search
/// keywords generated from CLDR annotations. Keyword tables load lazily, one
/// per enabled language, and are searched together — so "coeur", "inimă", and
/// "heart" all find ❤️ when those languages are enabled.
final class EmojiStore {
    static let shared = EmojiStore()

    struct Item {
        let emoji: String
        let group: Int
    }

    private(set) var groups: [String] = []
    private(set) var items: [Item] = []
    private var orderIndex: [String: Int] = [:]
    /// language code ("en") → emoji → folded keywords
    private var keywordCache: [String: [String: [String]]] = [:]

    private static let recentsKey = "emoji_recents"
    private static let maxRecents = 24

    private init() {
        guard let url = Bundle(for: EmojiStore.self).url(forResource: "emoji", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groupNames = parsed["groups"] as? [String],
              let list = parsed["emoji"] as? [[String: Any]] else { return }
        groups = groupNames
        items = list.compactMap { entry in
            guard let emoji = entry["e"] as? String, let group = entry["g"] as? Int else { return nil }
            return Item(emoji: emoji, group: group)
        }
        for (index, item) in items.enumerated() {
            orderIndex[item.emoji] = index
        }
    }

    var isLoaded: Bool { !items.isEmpty }

    func items(inGroup group: Int) -> [Item] {
        items.filter { $0.group == group }
    }

    // MARK: - Search

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    private func keywords(for languageCode: String) -> [String: [String]] {
        if let cached = keywordCache[languageCode] { return cached }
        var table: [String: [String]] = [:]
        if let url = Bundle(for: EmojiStore.self).url(forResource: "keywords-\(languageCode)", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] {
            table = parsed.mapValues { $0.map(Self.fold) }
        }
        keywordCache[languageCode] = table
        return table
    }

    /// Search across all given language codes at once. Results ranked:
    /// whole-keyword prefix match first, then word-prefix match, then grid order.
    func search(_ query: String, languageCodes: [String]) -> [String] {
        let folded = Self.fold(query.trimmingCharacters(in: .whitespaces))
        guard folded.count >= 2 else { return [] }

        var scores: [String: Int] = [:]
        for code in languageCodes {
            for (emoji, words) in keywords(for: code) {
                guard orderIndex[emoji] != nil else { continue }
                var best: Int? = nil
                for word in words {
                    if word == folded { best = 0; break }
                    if word.hasPrefix(folded) { best = min(best ?? 1, 1) }
                    else if word.contains(" " + folded) || word.split(separator: " ").contains(where: { $0.hasPrefix(folded) }) {
                        best = min(best ?? 2, 2)
                    }
                }
                if let best {
                    scores[emoji] = min(scores[emoji] ?? best, best)
                }
            }
        }
        return scores.keys.sorted {
            let s0 = scores[$0]!, s1 = scores[$1]!
            if s0 != s1 { return s0 < s1 }
            return (orderIndex[$0] ?? .max) < (orderIndex[$1] ?? .max)
        }
        .prefix(40).map { $0 }
    }

    // MARK: - Recents

    var recents: [String] {
        (AppGroup.defaults.stringArray(forKey: Self.recentsKey) ?? [])
            .filter { orderIndex[$0] != nil }
    }

    func addRecent(_ emoji: String) {
        var list = AppGroup.defaults.stringArray(forKey: Self.recentsKey) ?? []
        list.removeAll { $0 == emoji }
        list.insert(emoji, at: 0)
        if list.count > Self.maxRecents { list = Array(list.prefix(Self.maxRecents)) }
        AppGroup.defaults.set(list, forKey: Self.recentsKey)
    }
}
