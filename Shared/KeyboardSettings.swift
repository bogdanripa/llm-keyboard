import Foundation

/// App Group shared between the container app, the Settings.bundle, and the keyboard extension.
enum AppGroup {
    static let identifier = "group.com.bogdanripa.llmkeyboard"
    static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard
}

struct KeyboardLanguage: Identifiable, Equatable, Hashable {
    let id: String            // BCP-47, e.g. "en-US"
    let name: String          // English name
    let autonym: String       // name in its own language, shown on the space bar
    let settingsKey: String   // UserDefaults key, matches Settings.bundle Root.plist
    let spellCheckerLanguage: String // UITextChecker language code, e.g. "en_US"
    let accents: [String: String]    // long-press accent variants per base letter
}

enum KeyboardSettings {
    static let llmEnabledKey = "llm_predictions"
    static let autocorrectKey = "autocorrect"

    /// Latin-script languages supported by both this keyboard's QWERTY layout
    /// and Apple's on-device foundation model.
    static let allLanguages: [KeyboardLanguage] = [
        KeyboardLanguage(
            id: "en-US", name: "English", autonym: "English",
            settingsKey: "lang_en", spellCheckerLanguage: "en_US",
            accents: [:]),
        KeyboardLanguage(
            id: "es-ES", name: "Spanish", autonym: "Español",
            settingsKey: "lang_es", spellCheckerLanguage: "es_ES",
            accents: ["a": "á", "e": "é", "i": "í", "o": "ó", "u": "úü", "n": "ñ"]),
        KeyboardLanguage(
            id: "fr-FR", name: "French", autonym: "Français",
            settingsKey: "lang_fr", spellCheckerLanguage: "fr_FR",
            accents: ["a": "àâæ", "e": "éèêë", "i": "îï", "o": "ôœ", "u": "ùûü", "c": "ç", "y": "ÿ"]),
        KeyboardLanguage(
            id: "de-DE", name: "German", autonym: "Deutsch",
            settingsKey: "lang_de", spellCheckerLanguage: "de_DE",
            accents: ["a": "ä", "o": "ö", "u": "ü", "s": "ß"]),
        KeyboardLanguage(
            id: "it-IT", name: "Italian", autonym: "Italiano",
            settingsKey: "lang_it", spellCheckerLanguage: "it_IT",
            accents: ["a": "à", "e": "èé", "i": "ì", "o": "ò", "u": "ù"]),
        KeyboardLanguage(
            id: "pt-BR", name: "Portuguese", autonym: "Português",
            settingsKey: "lang_pt", spellCheckerLanguage: "pt_BR",
            accents: ["a": "áàâã", "e": "éê", "i": "í", "o": "óôõ", "u": "úü", "c": "ç"]),
        KeyboardLanguage(
            id: "ro-RO", name: "Romanian", autonym: "Română",
            settingsKey: "lang_ro", spellCheckerLanguage: "ro_RO",
            accents: ["a": "ăâ", "i": "î", "s": "ș", "t": "ț"]),
    ]

    /// Register defaults so toggles report correct values before the user
    /// ever opens the Settings app (Settings.bundle only writes on change).
    static func registerDefaults() {
        var defaults: [String: Any] = [
            llmEnabledKey: true,
            autocorrectKey: true,
        ]
        for language in allLanguages {
            defaults[language.settingsKey] = (language.settingsKey == "lang_en")
        }
        AppGroup.defaults.register(defaults: defaults)
    }

    static var enabledLanguages: [KeyboardLanguage] {
        let enabled = allLanguages.filter { AppGroup.defaults.bool(forKey: $0.settingsKey) }
        // Never allow zero languages: fall back to English.
        return enabled.isEmpty ? [allLanguages[0]] : enabled
    }

    static var llmEnabled: Bool {
        AppGroup.defaults.bool(forKey: llmEnabledKey)
    }

    static var autocorrectEnabled: Bool {
        AppGroup.defaults.bool(forKey: autocorrectKey)
    }

    /// Accent map merged across all enabled languages, for long-press popups.
    static func mergedAccents(for languages: [KeyboardLanguage]) -> [String: [String]] {
        var merged: [String: [String]] = [:]
        for language in languages {
            for (base, variants) in language.accents {
                var list = merged[base] ?? []
                for scalar in variants.map(String.init) where !list.contains(scalar) {
                    list.append(scalar)
                }
                merged[base] = list
            }
        }
        return merged
    }
}
