import AppKit
import SwiftUI
import Observation

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    private let model: EditorModel
    var onClose: (() -> Void)?
    private var trimButton: NSButton?
    private var muteButton: NSButton?

    init(source: URL) {
        model = EditorModel(source: source)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 530),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = source.deletingPathExtension().lastPathComponent
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: EditorView(model: model))
        super.init(window: window)
        window.delegate = self
        let toolbar = NSToolbar(identifier: "KappEditor")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        observeControls()
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func windowWillClose(_ notification: Notification) {
        model.close()
        onClose?()
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.trim, .mute, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.trim, .mute, .flexibleSpace]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let trim = identifier == .trim
        let title = trim ? "Trim" : "Mute"
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = title
        item.toolTip = trim ? "Trim (⌘T)" : "Mute Audio"
        let button = NSButton(title: title, target: self, action: trim ? #selector(trimRecording) : #selector(toggleMute))
        button.image = NSImage(systemSymbolName: trim ? "scissors" : "speaker.slash", accessibilityDescription: title)
        button.imagePosition = .imageOnly
        button.bezelStyle = .texturedRounded
        button.toolTip = item.toolTip
        if trim {
            button.keyEquivalent = "t"
            button.keyEquivalentModifierMask = .command
            trimButton = button
        } else {
            button.setButtonType(.toggle)
            muteButton = button
        }
        item.view = button
        return item
    }

    private func observeControls() {
        withObservationTracking {
            let canTrim = model.canTrim && model.range != nil && !model.isExporting && !model.isTrimming
            let canMute = !model.isExporting && model.format == .mp4
            let muted = model.muted
            trimButton?.isEnabled = canTrim
            muteButton?.isEnabled = canMute
            muteButton?.state = muted ? .on : .off
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeControls() }
        }
    }

    @objc private func trimRecording() { Task { await model.trim() } }
    @objc private func toggleMute() { model.muted.toggle() }
}

private extension NSToolbarItem.Identifier {
    static let trim = NSToolbarItem.Identifier("KappTrim")
    static let mute = NSToolbarItem.Identifier("KappMute")
}
