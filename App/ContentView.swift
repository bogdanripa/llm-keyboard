import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

struct ContentView: View {
    @AppStorage(KeyboardSettings.llmEnabledKey, store: AppGroup.defaults) private var llmEnabled = true
    @AppStorage(KeyboardSettings.autocorrectKey, store: AppGroup.defaults) private var autocorrectEnabled = true
    @State private var testText = ""
    @State private var refreshToken = false

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                setupSection
                aiStatusSection
                languagesSection
                behaviorSection
                testSection
                privacySection
            }
            .navigationTitle("LLM Keys")
        }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "keyboard.badge.eye")
                    .font(.system(size: 40))
                    .foregroundStyle(.linearGradient(colors: [.indigo, .purple],
                                                     startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 4) {
                    Text("LLM Keys").font(.title2.bold())
                    Text("On-device AI predictions, typo fixes, and multilingual typing. Nothing you type ever leaves your iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var setupSection: some View {
        Section("Set up") {
            VStack(alignment: .leading, spacing: 10) {
                Label("Open Settings for this app", systemImage: "1.circle.fill")
                Label("Tap **Keyboards** and turn on **LLM Keys**", systemImage: "2.circle.fill")
                Label("In any app, hold the 🌐 globe key and pick LLM Keys", systemImage: "3.circle.fill")
            }
            .font(.subheadline)
            .padding(.vertical, 2)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Keyboard Settings", systemImage: "gear")
            }
        }
    }

    @ViewBuilder
    private var aiStatusSection: some View {
        Section("Apple Intelligence") {
            if #available(iOS 26.0, *) {
                AIStatusRow()
            } else {
                Label {
                    Text("Requires iOS 26 or later. The keyboard still works with standard predictions.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                .font(.subheadline)
            }
        }
    }

    private var languagesSection: some View {
        Section {
            ForEach(KeyboardSettings.allLanguages) { language in
                Toggle(isOn: languageBinding(language)) {
                    HStack {
                        Text(language.name)
                        Text(language.autonym)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Languages")
        } footer: {
            Text("Also available in the Settings app → Apps → LLM Keys. The keyboard auto-detects which enabled language you're typing.")
        }
    }

    private func languageBinding(_ language: KeyboardLanguage) -> Binding<Bool> {
        Binding(
            get: {
                _ = refreshToken
                return AppGroup.defaults.bool(forKey: language.settingsKey)
            },
            set: { newValue in
                // Keep at least one language enabled.
                let enabledCount = KeyboardSettings.allLanguages
                    .filter { AppGroup.defaults.bool(forKey: $0.settingsKey) }.count
                if !newValue && enabledCount <= 1 { return }
                AppGroup.defaults.set(newValue, forKey: language.settingsKey)
                refreshToken.toggle()
            }
        )
    }

    private var behaviorSection: some View {
        Section("Typing") {
            Toggle("AI predictions & fixes", isOn: $llmEnabled)
            Toggle("Auto-correction", isOn: $autocorrectEnabled)
        }
    }

    private var testSection: some View {
        Section("Try it") {
            TextField("Type here with LLM Keys…", text: $testText, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Label {
                Text("The keyboard runs entirely on-device using Apple's foundation model. It does not request network access, does not require Full Access, and collects no data.")
                    .font(.footnote)
            } icon: {
                Image(systemName: "lock.shield.fill").foregroundStyle(.green)
            }
        }
    }
}

@available(iOS 26.0, *)
private struct AIStatusRow: View {
    var body: some View {
        switch SystemLanguageModel.default.availability {
        case .available:
            Label {
                Text("On-device model ready. Predictions and typo fixes are powered by Apple Intelligence.")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            }
        case .unavailable(.appleIntelligenceNotEnabled):
            Label {
                Text("Turn on Apple Intelligence in Settings → Apple Intelligence & Siri to unlock AI predictions.")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            }
        case .unavailable(.deviceNotEligible):
            Label {
                Text("This device doesn't support Apple Intelligence. The keyboard works with standard predictions.")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }
        case .unavailable(.modelNotReady):
            Label {
                Text("The on-device model is downloading. AI predictions will activate automatically.")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.blue)
            }
        case .unavailable:
            Label {
                Text("The on-device model is temporarily unavailable.")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            }
        }
    }
}

#Preview {
    ContentView()
}
