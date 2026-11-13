import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = RecorderModel()
    private var statusItem: NSStatusItem?
    private var shortcut: RecordingShortcut?
    private var editors: [UUID: EditorWindowController] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        model.onError = { [weak self] error in self?.showError(error) }
        model.onFinished = { [weak self] source in self?.openEditor(source: source) }
        observeRecordingState()
        do {
            shortcut = try RecordingShortcut { [weak self] in self?.toggleRecording() }
        } catch { showError(error) }
    }

    private func observeRecordingState() {
        withObservationTracking {
            let state = model.session.state
            let symbol = state == .paused ? "pause.circle.fill" : state.isRecording ? "stop.circle.fill" : "record.circle"
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Kapp")
            image?.isTemplate = true
            statusItem?.button?.image = image
            statusItem?.button?.toolTip = state.isRecording ? "Stop Recording (⌘⇧5)" : "Select Area (⌘⇧5)"
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeRecordingState() }
        }
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu() } else { toggleRecording() }
    }

    private func toggleRecording() {
        if model.session.state.isRecording {
            Task { await model.stop() }
        } else if model.isSelecting {
            model.cancelSelection()
        } else if model.canSelect {
            Task { await model.selectArea() }
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        if model.session.state.isRecording {
            addItem("Stop Recording", action: #selector(stopRecording), to: menu)
            addItem(model.session.state == .paused ? "Resume" : "Pause", action: #selector(togglePause), to: menu)
        } else {
            addItem("Record Area…", action: #selector(recordArea), to: menu, enabled: model.canSelect)
            addItem("Record Screen or Window…", action: #selector(recordContent), to: menu, enabled: model.canSelect)
        }
        menu.addItem(.separator())
        addItem("Microphone", action: #selector(toggleMicrophone), to: menu,
                enabled: model.canSelect, checked: model.configuration.captureMicrophone)
        addItem("System Audio", action: #selector(toggleSystemAudio), to: menu,
                enabled: model.canSelect, checked: model.configuration.captureSystemAudio)
        addItem("Show Cursor", action: #selector(toggleCursor), to: menu,
                enabled: model.canSelect, checked: model.configuration.showCursor)
        menu.addItem(.separator())
        addItem("Open Recording…", action: #selector(openRecording), to: menu, enabled: model.canSelect)
        addItem("Quit Kapp", action: #selector(quit), to: menu)
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func addItem(_ title: String, action: Selector, to menu: NSMenu,
                         enabled: Bool = true, checked: Bool = false) {
        menu.autoenablesItems = false
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        item.state = checked ? .on : .off
        menu.addItem(item)
    }

    @objc private func recordArea() { Task { await model.selectArea() } }
    @objc private func recordContent() { Task { await model.selectContent() } }
    @objc private func stopRecording() { Task { await model.stop() } }
    @objc private func togglePause() { model.session.togglePause() }
    @objc private func toggleMicrophone() { model.configuration.captureMicrophone.toggle() }
    @objc private func toggleSystemAudio() { model.configuration.captureSystemAudio.toggle() }
    @objc private func toggleCursor() { model.configuration.showCursor.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func openRecording() {
        guard model.canSelect else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard let self else { return }
            if response == .OK, let url = panel.url { self.openEditor(source: url) }
            else if self.editors.isEmpty { NSApp.setActivationPolicy(.accessory) }
        }
    }

    private func showError(_ error: Error) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Kapp"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func openEditor(source: URL) {
        let id = UUID()
        let editor = EditorWindowController(source: source)
        editor.onClose = { [weak self] in
            guard let self else { return }
            self.editors.removeValue(forKey: id)
            if self.editors.isEmpty { NSApp.setActivationPolicy(.accessory) }
        }
        editors[id] = editor
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        editor.showWindow(nil)
        editor.window?.makeKeyAndOrderFront(nil)
        editor.window?.orderFrontRegardless()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.session.state.isRecording {
            Task {
                await model.stop()
                sender.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
        guard model.session.state == .idle else { return .terminateCancel }
        model.cancelSelection()
        return .terminateNow
    }
}
