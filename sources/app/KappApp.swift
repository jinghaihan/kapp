import KappLocalization
import SwiftUI

@main
struct KappApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appInfo) {
                    Button(tr("About Kapp")) { delegate.showAbout() }
                }
                CommandGroup(replacing: .appSettings) {
                    Button(tr("Preferences…")) { delegate.showPreferences() }
                        .keyboardShortcut(",", modifiers: .command)
                }
                CommandGroup(after: .appInfo) {
                    Button(tr("Check for Updates…")) { delegate.checkForUpdates() }
                }
                CommandGroup(after: .newItem) {
                    Button(tr("Open Video…")) { delegate.openRecording() }
                        .keyboardShortcut("o", modifiers: .command)
                }
            }
    }
}
