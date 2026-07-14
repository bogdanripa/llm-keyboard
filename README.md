# LLM Keys

An iOS keyboard powered by Apple's on-device foundation model (FoundationModels, iOS 26).

- **Smart predictions** — the LLM reads the full visible context of the text field and suggests next words/phrases in the suggestion strip.
- **Contextual typo fixing** — dictionary autocorrect on word boundaries, plus LLM-detected contextual fixes (their/there, grammar slips) offered as ✦ suggestions.
- **Multilingual** — English, Spanish, French, German, Italian, Portuguese with automatic language detection while typing, long-press accent popups, per-language spellcheck.
- **Private by design** — no Full Access, no network, no data collection. Inference runs in Apple's system process, so the model doesn't count against the keyboard extension's memory cap.

## Architecture

| Path | What it is |
|---|---|
| `App/` | SwiftUI container app: onboarding, settings, AI status, test field |
| `App/Settings.bundle` | Language & behavior settings shown in the iOS Settings app; stored directly in the App Group via `ApplicationGroupContainerIdentifier` |
| `Keyboard/` | The keyboard extension (UIKit): layout, keys, suggestion strip, prediction engine |
| `Shared/` | App Group constants + language/settings definitions used by both targets |

Two-tier prediction: `UITextChecker`/`UILexicon` gives instant per-keystroke completions; a debounced (350 ms) `LanguageModelSession` pass rewrites the strip with context-aware predictions and corrections. Falls back gracefully on devices without Apple Intelligence (deployment target iOS 17).

## Building

```bash
brew install xcodegen
xcodegen generate
open LLMKeyboard.xcodeproj
```

Bundle IDs `com.bogdanripa.llmkeyboard` (+ `.keyboard`), App Group `group.com.bogdanripa.llmkeyboard`, team `Y6SUP9Q5H2`.

See [PUBLISHING.md](PUBLISHING.md) for App Store submission.
