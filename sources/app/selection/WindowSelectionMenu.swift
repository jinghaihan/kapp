import KappLocalization
import AppKit
@preconcurrency import ScreenCaptureKit

// Kap presents a native, app-icon menu and remembers recently selected windows.
@MainActor
final class WindowSelectionMenu: NSObject {
    private let windows: [SCWindow]
    private let onSelect: (SCWindow) -> Void

    private init(windows: [SCWindow], onSelect: @escaping (SCWindow) -> Void) {
        self.windows = windows
        self.onSelect = onSelect
    }

    static func present(windows: [SCWindow], selected: SCWindow?, in view: NSView,
                        onSelect: @escaping (SCWindow) -> Void) {
        let history = UserDefaults.standard.dictionary(forKey: "window-usage") as? [String: [String: Double]] ?? [:]
        let recent = history.values.compactMap { $0["lastUsed"] }.max() ?? 0
        let sorted = windows.filter {
            $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier && $0.isOnScreen &&
            $0.frame.width >= 24 && $0.frame.height >= 24 && $0.owningApplication != nil
        }.sorted {
            let left = history[String($0.owningApplication!.processID)] ?? [:]
            let right = history[String($1.owningApplication!.processID)] ?? [:]
            if (left["lastUsed"] ?? 0) == recent && (right["lastUsed"] ?? 0) != recent { return true }
            if (right["lastUsed"] ?? 0) == recent && (left["lastUsed"] ?? 0) != recent { return false }
            return (left["count"] ?? 0) > (right["count"] ?? 0)
        }
        let controller = WindowSelectionMenu(windows: sorted, onSelect: onSelect)
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (index, window) in sorted.enumerated() {
            guard let app = window.owningApplication else { continue }
            let item = NSMenuItem(title: app.applicationName, action: #selector(selectWindow), keyEquivalent: "")
            item.target = controller
            item.tag = index
            item.state = selected?.owningApplication?.processID == app.processID ? .on : .off
            if let image = NSRunningApplication(processIdentifier: app.processID)?.icon?.copy() as? NSImage {
                image.size = NSSize(width: 16, height: 16)
                item.image = image
            }
            menu.addItem(item)
        }
        if menu.items.isEmpty {
            let item = NSMenuItem(title: tr("No windows available"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        _ = withExtendedLifetime(controller) {
            menu.popUp(positioning: nil, at: NSPoint(x: 132, y: view.isFlipped ? 44 : 20), in: view)
        }
    }

    @objc private func selectWindow(_ sender: NSMenuItem) {
        let window = windows[sender.tag]
        if let app = window.owningApplication {
            var history = UserDefaults.standard.dictionary(forKey: "window-usage") as? [String: [String: Double]] ?? [:]
            let key = String(app.processID)
            history[key] = ["count": (history[key]?["count"] ?? 0) + 1, "lastUsed": Date.now.timeIntervalSince1970]
            UserDefaults.standard.set(history, forKey: "window-usage")
            NSRunningApplication(processIdentifier: app.processID)?.activate()
        }
        onSelect(window)
    }
}
