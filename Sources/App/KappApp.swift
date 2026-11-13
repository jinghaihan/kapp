import SwiftUI

@main
struct KappApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(after: .newItem) {
                    Button("Open Recording…") { delegate.openRecording() }
                        .keyboardShortcut("o", modifiers: .command)
                }
            }
    }
}
