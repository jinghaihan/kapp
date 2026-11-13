import SwiftUI

@main
struct KappApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appInfo) {
                    Button("About Kapp") { delegate.showAbout() }
                }
                CommandGroup(replacing: .appSettings) {
                    Button("Preferences…") { delegate.showPreferences() }
                        .keyboardShortcut(",", modifiers: .command)
                }
                CommandGroup(after: .newItem) {
                    Button("Open Video…") { delegate.openRecording() }
                        .keyboardShortcut("o", modifiers: .command)
                }
            }
    }
}
