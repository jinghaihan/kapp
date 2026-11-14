import KappLocalization
import AppKit
import SwiftUI

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    private let model: EditorModel
    private let isNewRecording: Bool
    private let recordingFiles: RecordingFiles
    var onClose: (() -> Void)?
    var confirmDiscard: (NSWindow) -> Bool = { _ in
        let alert = NSAlert()
        alert.messageText = tr("Are you sure that you want to discard this recording?")
        alert.informativeText = tr("The original recording will be deleted.")
        alert.addButton(withTitle: tr("Discard"))
        alert.addButton(withTitle: tr("Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    init(source: URL, isNewRecording: Bool = false, recordingFiles: RecordingFiles = .shared) {
        model = EditorModel(source: source)
        self.isNewRecording = isNewRecording
        self.recordingFiles = recordingFiles
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 530),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = source.lastPathComponent
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenPrimary]
        window.isReleasedWhenClosed = false
        window.isDocumentEdited = isNewRecording
        window.contentView = NSHostingView(rootView: EditorView(model: model))
        super.init(window: window)
        window.delegate = self
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isNewRecording else { return true }
        return confirmDiscard(sender)
    }

    func windowDidResignKey(_ notification: Notification) {
        model.windowFocusChanged(isFocused: false)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.windowFocusChanged(isFocused: true)
    }

    func windowWillClose(_ notification: Notification) {
        recordingFiles.finishEditing(isNewRecording ? model.source : nil, after: model.close())
        window?.orderOut(nil)
        window?.contentView = nil
        onClose?()
    }

}
