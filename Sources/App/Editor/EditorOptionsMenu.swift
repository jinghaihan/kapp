import AppKit

// Keep Kap's compact button appearance while using native macOS menu interaction.
@MainActor
final class EditorOptionsMenu: NSObject {
    private let onSelect: (Int) -> Void

    private init(onSelect: @escaping (Int) -> Void) {
        self.onSelect = onSelect
    }

    static func present(titles: [String], selected: Int, onSelect: @escaping (Int) -> Void) {
        guard let event = NSApp.currentEvent, let view = event.window?.contentView else { return }
        let controller = EditorOptionsMenu(onSelect: onSelect)
        let menu = NSMenu()
        for (index, title) in titles.enumerated() {
            let item = NSMenuItem(title: title, action: #selector(selectOption), keyEquivalent: "")
            item.target = controller
            item.tag = index
            item.state = index == selected ? .on : .off
            menu.addItem(item)
        }
        _ = withExtendedLifetime(controller) {
            menu.popUp(positioning: menu.items[selected], at: event.locationInWindow, in: view)
        }
    }

    @objc private func selectOption(_ sender: NSMenuItem) {
        onSelect(sender.tag)
    }
}
