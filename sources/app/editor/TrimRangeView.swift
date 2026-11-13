// Rendering follows Kap's 4px progress track and 5×16px trim handles.
// MIT; see third-party-licenses/Kap.txt.
import AppKit
import SwiftUI

struct TrimRangeView: NSViewRepresentable {
    let model: EditorModel

    func makeNSView(context: Context) -> TrimRangeControl {
        let view = TrimRangeControl()
        view.model = model
        return view
    }

    func updateNSView(_ view: TrimRangeControl, context: Context) {
        view.duration = model.fullDuration
        let changed = view.range != model.range
        view.range = model.range
        view.time = model.currentTime
        view.isEnabled = !model.isExporting
        view.needsDisplay = true
        if changed { view.window?.invalidateCursorRects(for: view) }
    }
}

@MainActor
final class TrimRangeControl: NSView {
    weak var model: EditorModel?
    var duration = 0.0
    var range: ClipRange?
    var time = 0.0
    var isEnabled = true
    private enum DragTarget { case start, end, seek }
    private var dragging: DragTarget?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Trim Range")
        toolTip = "Drag the left and right handles to trim. Click the track to seek."
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        guard let range, duration > 0 else { return }
        let y = bounds.midY - 2
        let start = x(range.start)
        let end = x(range.end)
        NSColor.white.withAlphaComponent(0.2).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: y, width: bounds.width, height: 4), xRadius: 2, yRadius: 2).fill()
        NSColor.white.withAlphaComponent(0.4).setFill()
        NSBezierPath(roundedRect: NSRect(x: start, y: y, width: end - start, height: 4), xRadius: 2, yRadius: 2).fill()
        let progress = NSBezierPath(roundedRect: NSRect(x: start, y: y, width: max(0, min(end, x(time)) - start), height: 4), xRadius: 2, yRadius: 2)
        NSGradient(colors: [NSColor(red: 0.576, green: 0, blue: 1, alpha: 1),
                            NSColor(red: 0.322, green: 0.447, blue: 0.886, alpha: 1),
                            NSColor(red: 0.02, green: 0.902, blue: 0.71, alpha: 1)])?.draw(in: progress, angle: 0)
        NSColor.white.setFill()
        for center in [start, end] {
            NSBezierPath(roundedRect: NSRect(x: center - 2.5, y: bounds.midY - 8, width: 5, height: 16), xRadius: 2, yRadius: 2).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let range else { return }
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let startDistance = abs(point.x - x(range.start))
        let endDistance = abs(point.x - x(range.end))
        dragging = min(startDistance, endDistance) <= 10 ? (startDistance <= endDistance ? .start : .end) : .seek
        model?.beginDragging()
        update(at: point.x)
    }

    override func resetCursorRects() {
        guard let range else { return }
        for time in [range.start, range.end] {
            addCursorRect(NSRect(x: x(time) - 10, y: 0, width: 20, height: bounds.height), cursor: .resizeLeftRight)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragging != nil else { return }
        update(at: convert(event.locationInWindow, from: nil).x)
    }

    override func mouseUp(with event: NSEvent) {
        guard dragging != nil else { return }
        update(at: convert(event.locationInWindow, from: nil).x)
        dragging = nil
        model?.endDragging()
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        switch event.keyCode {
        case 49: model?.togglePlayback()
        case 123: model?.seek(to: time - 1.0 / 30)
        case 124: model?.seek(to: time + 1.0 / 30)
        default: super.keyDown(with: event)
        }
    }

    private func update(at position: Double) {
        let value = TrimGeometry.time(at: position, duration: duration, width: bounds.width)
        switch dragging {
        case .start: model?.updateTrim(start: value)
        case .end: model?.updateTrim(end: value)
        case .seek: model?.seek(to: value)
        case nil: break
        }
    }

    private func x(_ time: Double) -> Double {
        TrimGeometry.position(for: time, duration: duration, width: bounds.width)
    }
}
