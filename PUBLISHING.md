# Publishing LLM Keys to the App Store

## Prerequisites
- Paid Apple Developer Program membership on team `Y6SUP9Q5H2` (a free account can install on your own phone but cannot ship to the App Store).
- A public privacy policy URL (required for all apps). Ready-to-host text is below.

## 1. Create the app record
1. Go to [App Store Connect](https://appstoreconnect.apple.com) → Apps → **+** → New App.
2. Platform **iOS**, Name **LLM Keys** (pick an alternative if taken, e.g. "LLM Keys – AI Keyboard").
3. Bundle ID: `com.bogdanripa.llmkeyboard` (register it at [developer.apple.com/account](https://developer.apple.com/account/resources/identifiers) first if it's not offered in the dropdown — automatic signing already registered it for development).
4. SKU: `llmkeyboard-001`.

## 2. Archive and upload
In Xcode: open `LLMKeyboard.xcodeproj`, select the **LLMKeyboard** scheme and destination **Any iOS Device (arm64)**, then **Product → Archive**, and in the Organizer click **Distribute App → App Store Connect**.

Or from the terminal:
```bash
xcodebuild -project LLMKeyboard.xcodeproj -scheme LLMKeyboard \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates \
  archive -archivePath build/LLMKeyboard.xcarchive

xcodebuild -exportArchive -archivePath build/LLMKeyboard.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates
# then upload build/export/LLMKeyboard.ipa via Xcode Organizer,
# `xcrun altool`, or the Transporter app
```

## 3. Metadata suggestions
- **Subtitle:** AI predictions, on device
- **Description (draft):**
  > LLM Keys is a keyboard powered by Apple's on-device foundation model. It predicts your next words from the full context of what you're writing, fixes typos and wrong words ("their" vs "there") the way a human proofreader would, and types fluently in English, Spanish, French, German, Italian, and Portuguese — auto-detecting the language as you type.
  >
  > Private by design: LLM Keys never requests Full Access, never connects to the network, and never collects any data. Everything happens on your iPhone.
  >
  > AI predictions require an iPhone with Apple Intelligence (iPhone 15 Pro or later, iOS 26). On other devices the keyboard works with standard predictions.
- **Keywords:** keyboard,AI,autocorrect,predictions,typing,multilingual,spanish,french,german,LLM
- **Category:** Utilities. **Age rating:** 4+.
- **Screenshots:** required for 6.9" (iPhone 17 Pro Max class) and 6.5". Take them on your phone with the keyboard open in Messages/Notes (the in-app "Try it" field works too).

## 4. App Privacy
Select **Data Not Collected** — true for this app: no network, no Full Access, no analytics.

## 5. Review notes (paste into "Notes for Review")
> The keyboard extension does NOT request Open Access (RequestsOpenAccess = false) and has no network capability. Text predictions and typo corrections run entirely on-device via Apple's FoundationModels framework (iOS 26+, Apple Intelligence). On devices without Apple Intelligence the keyboard falls back to UITextChecker-based predictions, so it is fully functional everywhere. Language selection lives in the iOS Settings app (Settings → Apps → LLM Keys) and in the container app.

## 6. Privacy policy (host this text at any public URL)
> **LLM Keys Privacy Policy** — LLM Keys does not collect, store, transmit, or share any data. The keyboard extension does not request Full Access and has no ability to make network requests. All text processing (predictions, corrections) happens on your device using Apple's on-device models. Settings (enabled languages, toggles) are stored locally on your device only. Contact: bogdanripa@gmail.com

A GitHub Pages file, a gist, or a page on your own site all work.

## Known review considerations
- Keyboard extensions must be usable without network and without Full Access — this one is, by design.
- Apple requires the container app to "provide help/settings" — the app includes setup steps, settings, and a test field, which satisfies this.
