import KappLocalization
import AppKit
import SwiftUI
import Observation

@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = tr("Preferences")
        window.contentMinSize = NSSize(width: 500, height: 440)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PreferencesView(settings: settings))
        super.init(window: window)
        window.delegate = self
        observeLanguage()
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func observeLanguage() {
        withObservationTracking {
            window?.title = tr("Preferences")
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeLanguage() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        settings.setRecordingShortcut(false)
        window?.orderOut(nil)
        window?.contentView = nil
        onClose?()
    }
}
