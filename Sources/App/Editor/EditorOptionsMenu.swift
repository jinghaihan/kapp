import AppKit
import SwiftUI

// Keep Kap's compact button appearance while using native macOS menu interaction.
@MainActor
final class EditorOptionsMenu: NSObject {
    private let onSelect: (Int) -> Void

    private init(onSelect: @escaping (Int) -> Void) {
        self.onSelect = onSelect
    }

    static func present(titles: [String], selected: Int, anchoredTo view: NSView, onSelect: @escaping (Int) -> Void) {
        guard view.window != nil else { return }
        let controller = EditorOptionsMenu(onSelect: onSelect)
        let menu = NSMenu()
        menu.minimumWidth = view.bounds.width
        for (index, title) in titles.enumerated() {
            let item = NSMenuItem(title: title, action: #selector(selectOption), keyEquivalent: "")
            item.target = controller
            item.tag = index
            item.state = index == selected ? .on : .off
            menu.addItem(item)
        }
        _ = withExtendedLifetime(controller) {
            menu.popUp(positioning: menu.items[selected],
                       at: NSPoint(x: view.bounds.minX, y: view.bounds.midY), in: view)
        }
    }

    @objc private func selectOption(_ sender: NSMenuItem) {
        onSelect(sender.tag)
    }
}

struct EditorMenuAnchor: NSViewRepresentable {
    let view: NSView

    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
