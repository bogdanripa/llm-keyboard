import SwiftUI

@main
struct LLMKeyboardApp: App {
    init() {
        KeyboardSettings.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
