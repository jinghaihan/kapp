import KappLocalization
import AppKit
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    let settings: AppSettings

    func makeNSView(context: Context) -> ShortcutRecorderControl {
        let view = ShortcutRecorderControl()
        view.settings = settings
        view.setAccessibilityLabel(tr("Recording shortcut"))
        return view
    }

    func updateNSView(_ view: ShortcutRecorderControl, context: Context) {
        view.settings = settings
        view.isEnabled = settings.shortcutsEnabled
        view.setAccessibilityValue(settings.shortcut.displayName)
        view.needsDisplay = true
    }

    static func dismantleNSView(_ view: ShortcutRecorderControl, coordinator: Void) {
        view.finishRecording()
    }
}

@MainActor
final class ShortcutRecorderControl: NSControl {
    weak var settings: AppSettings?
    private var recording = false
    override var acceptsFirstResponder: Bool { isEnabled }
    override func isAccessibilityElement() -> Bool { true }

    override func mouseDown(with event: NSEvent) { beginRecording() }

    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityPerformPress() -> Bool {
        beginRecording()
        return isEnabled
    }

    private func beginRecording() {
        guard isEnabled, !recording, window?.makeFirstResponder(self) == true else { return }
        recording = true
        settings?.setRecordingShortcut(true)
        needsDisplay = true
    }

    func finishRecording() {
        guard recording else { return }
        recording = false
        settings?.setRecordingShortcut(false)
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        finishRecording()
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { return }
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }
        let shortcut = KeyboardShortcut(event: event)
        guard shortcut.isValid else { NSSound.beep(); return }
        settings?.setShortcut(shortcut)
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
        NSColor.controlBackgroundColor.setFill()
        border.fill()
        (recording ? NSColor.keyboardFocusIndicatorColor : NSColor.separatorColor).setStroke()
        border.lineWidth = 1
        border.stroke()
        let text = recording ? tr("Press shortcut…") : settings?.shortcut.displayName ?? ""
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: isEnabled ? NSColor.labelColor : NSColor.disabledControlTextColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}
