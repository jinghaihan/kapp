import AppKit

@MainActor
enum CaptureOptionsMenu {
    static func present(model: RecorderModel) {
        guard let event = NSApp.currentEvent, let view = event.window?.contentView,
              let menu = model.makeMenu?() else { return }
        let point = view.convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: NSPoint(x: point.x, y: point.y - 12), in: view)
    }
}
