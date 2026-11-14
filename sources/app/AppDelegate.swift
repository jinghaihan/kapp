import KappLocalization
import AppKit
import Observation
import Sparkle
import ScreenCaptureKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings.shared
    private let model = RecorderModel()
    private var statusItem: NSStatusItem?
    private var shortcut: RecordingShortcut?
    private var editors: [UUID: EditorWindowController] = [:]
    private var preferences: PreferencesWindowController?
    private var isTerminating = false
    private lazy var updater = SPUUpdater(hostBundle: .main, applicationBundle: .main,
                                         userDriver: UpdateUserDriver(hostBundle: .main, delegate: nil), delegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do { try updater.start() }
        catch { showError(error) }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = image
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        model.onError = { [weak self] error in self?.showError(error) }
        model.recordingFiles.onError = { [weak self] error in self?.showError(error) }
        model.onFinished = { [weak self] source in self?.openEditor(source: source, isNewRecording: true) }
        model.makeMenu = { [weak self] in self?.makeMenu() ?? NSMenu() }
        observeRecordingState()
        do {
            shortcut = try RecordingShortcut(binding: nil) { [weak self] in self?.toggleRecording() }
            settings.applyShortcut = { [weak self] value in try self?.shortcut?.update(value) }
            try shortcut?.update(settings.shortcutsEnabled ? settings.shortcut : nil)
        } catch { showError(error) }
    }

    private func observeRecordingState() {
        withObservationTracking {
            let state = model.session.state
            let symbol = state == .paused ? "pause.circle.fill" : state.isRecording ? "stop.circle.fill" : "record.circle"
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Kapp")
            image?.isTemplate = true
            statusItem?.button?.image = image
            let key = settings.shortcutsEnabled ? " (\(settings.shortcut.displayName))" : ""
            statusItem?.button?.toolTip = tr(state.isRecording ? "Stop Recording" : "Select Area") + key
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeRecordingState() }
        }
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else if model.session.state == .paused {
            model.session.togglePause()
        } else if model.session.state == .recording, NSEvent.modifierFlags.contains(.option) {
            model.session.togglePause()
        } else {
            toggleRecording()
        }
    }

    private func toggleRecording() {
        guard !isTerminating else { return }
        if model.session.state.isRecording {
            Task { await model.stop() }
        } else if model.isSelecting {
            model.cancelSelection()
        } else if model.canSelect {
            Task { await model.selectArea() }
        }
    }

    private func showMenu() {
        statusItem?.menu = makeMenu()
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        if model.session.state.isRecording {
            addItem("Stop Recording", action: #selector(stopRecording), to: menu)
            addItem(model.session.state == .paused ? "Resume" : "Pause", action: #selector(togglePause), to: menu)
        } else {
            addItem("About Kapp", action: #selector(showAbout), to: menu)
            addItem("Check for Updates…", action: #selector(checkForUpdates), to: menu)
            menu.items.last?.isEnabled = updater.canCheckForUpdates
            menu.addItem(.separator())
            addItem("Preferences…", action: #selector(showPreferences), key: ",", to: menu)
            menu.addItem(.separator())
            addItem("Open Video…", action: #selector(openRecording), key: "o", to: menu)
            menu.addItem(.separator())
            addItem("Quit Kapp", action: #selector(quit), key: "q", to: menu)
        }
        return menu
    }

    private func addItem(_ title: String, action: Selector, key: String = "", to menu: NSMenu) {
        menu.autoenablesItems = false
        let item = NSMenuItem(title: tr(title), action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func stopRecording() { Task { await model.stop() } }
    @objc private func togglePause() { model.session.togglePause() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func checkForUpdates() {
        guard !isTerminating, model.session.state == .idle else { return }
        model.cancelSelection()
        updater.checkForUpdates()
    }

    @objc func showAbout() {
        model.cancelSelection()
        NSApp.activate()
        let credits = NSAttributedString(string: "GitHub", attributes: [.link: URL(string: "https://github.com/jinghaihan/kapp")!])
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Kapp", .credits: credits])
    }

    @objc func showPreferences() {
        model.cancelSelection()
        if preferences == nil {
            let controller = PreferencesWindowController(settings: settings)
            controller.onClose = { [weak self] in
                self?.preferences = nil
                self?.restoreMenuBarMode()
            }
            preferences = controller
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        preferences?.showWindow(nil)
        preferences?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func openRecording() {
        guard !isTerminating, model.session.state == .idle else { return }
        model.cancelSelection()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard let self else { return }
            if response == .OK, let url = panel.url { self.openEditor(source: url) }
            else { self.restoreMenuBarMode() }
        }
    }

    private func showError(_ error: Error) {
        NSApp.activate()
        let alert = NSAlert()
        if (error as? SCStreamError)?.code == .userDeclined {
            alert.messageText = tr("Screen Recording Permission Required")
            alert.informativeText = tr("Enable Kapp in System Settings → Privacy & Security → Screen & System Audio Recording, then quit and reopen Kapp.\n\nIf Kapp is already enabled, remove it from the list and add this build again. Local rebuilds with an ad-hoc signature can invalidate the previous permission.")
            alert.addButton(withTitle: tr("Open System Settings"))
            alert.addButton(withTitle: tr("Cancel"))
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        alert.messageText = "Kapp"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func openEditor(source: URL, isNewRecording: Bool = false) {
        let id = UUID()
        let editor = EditorWindowController(source: source, isNewRecording: isNewRecording, recordingFiles: model.recordingFiles)
        editor.onClose = { [weak self] in
            guard let self else { return }
            self.editors.removeValue(forKey: id)
            self.restoreMenuBarMode()
        }
        editors[id] = editor
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        editor.showWindow(nil)
        editor.window?.makeKeyAndOrderFront(nil)
        editor.window?.orderFrontRegardless()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else { return .terminateLater }
        guard model.session.state.isRecording || model.session.state == .idle else { return .terminateCancel }
        isTerminating = true
        Task {
            if model.session.state.isRecording { await model.stop() }
            guard confirmClosingEditors() else {
                isTerminating = false
                sender.reply(toApplicationShouldTerminate: false)
                return
            }
            model.cancelSelection()
            // Discard was confirmed above; close directly without asking a second time.
            for editor in Array(editors.values) { editor.window?.close() }
            do { try await model.recordingFiles.cleanUpAll() }
            catch { showError(error) }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func confirmClosingEditors() -> Bool {
        for editor in Array(editors.values) {
            if let window = editor.window, !editor.windowShouldClose(window) { return false }
        }
        return true
    }

    private func restoreMenuBarMode() {
        // Wait until AppKit has removed the closing window before changing visibility.
        Task { @MainActor [weak self] in
            guard let self, self.editors.isEmpty, self.preferences == nil else { return }
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
