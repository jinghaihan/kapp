import AppKit

@MainActor
final class CaptureOptionsMenu: NSObject {
    private let model: RecorderModel
    private let cancel: () -> Void

    private init(model: RecorderModel, cancel: @escaping () -> Void) {
        self.model = model
        self.cancel = cancel
    }

    static func present(model: RecorderModel, cancel: @escaping () -> Void) {
        guard let event = NSApp.currentEvent, let view = event.window?.contentView else { return }
        let controller = CaptureOptionsMenu(model: model, cancel: cancel)
        let menu = NSMenu()
        for (title, action, enabled) in [
            ("Microphone", #selector(toggleMicrophone), model.configuration.captureMicrophone),
            ("System Audio", #selector(toggleSystemAudio), model.configuration.captureSystemAudio),
            ("Show Cursor", #selector(toggleCursor), model.configuration.showCursor)
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = controller
            item.state = enabled ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let dismiss = NSMenuItem(title: "Cancel", action: #selector(dismissSelection), keyEquivalent: "")
        dismiss.target = controller
        menu.addItem(dismiss)
        withExtendedLifetime(controller) {
            menu.popUp(positioning: nil, at: NSPoint(x: event.locationInWindow.x, y: event.locationInWindow.y - 12), in: view)
        }
    }

    @objc private func toggleMicrophone() { model.configuration.captureMicrophone.toggle() }
    @objc private func toggleSystemAudio() { model.configuration.captureSystemAudio.toggle() }
    @objc private func toggleCursor() { model.configuration.showCursor.toggle() }
    @objc private func dismissSelection() { cancel() }
}
