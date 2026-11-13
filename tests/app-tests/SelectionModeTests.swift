import AppKit
import Testing
import ScreenCaptureKit
@testable import Kapp

@MainActor
struct SelectionModeTests {
    @Test func exitingFullScreenRestoresThePreviousArea() throws {
        let screen = try #require(NSScreen.main)
        let view = AreaSelectionView(frame: CGRect(x: 0, y: 0, width: 600, height: 400),
                                     screen: screen, model: RecorderModel())
        let delegate = SelectionObserver()
        view.delegate = delegate
        draw(view, from: CGPoint(x: 50, y: 60), to: CGPoint(x: 220, y: 180))
        view.selectFullScreen()
        confirm(view)
        #expect(delegate.rect?.size == CGSize(width: 600, height: 400))
        view.showDimensions() // Kap ignores the crop control while fullscreen is selected.
        confirm(view)
        #expect(delegate.rect?.size == CGSize(width: 600, height: 400))
        view.selectFullScreen()
        confirm(view)
        #expect(delegate.rect == CGRect(x: screen.frame.minX + 50, y: screen.frame.minY + 60,
                                        width: 170, height: 120))
    }

    @Test func fullScreenCanReturnToAnEmptyCanvasAndDrawAgain() throws {
        let screen = try #require(NSScreen.main)
        let view = AreaSelectionView(frame: CGRect(x: 0, y: 0, width: 600, height: 400),
                                     screen: screen, model: RecorderModel())
        let delegate = SelectionObserver()
        view.delegate = delegate
        view.selectFullScreen()
        view.selectFullScreen()
        confirm(view)
        #expect(delegate.rect == nil)
        draw(view, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 350, y: 250))
        confirm(view)
        #expect(delegate.rect?.size == CGSize(width: 250, height: 150))
    }

    private func draw(_ view: AreaSelectionView, from start: CGPoint, to end: CGPoint) {
        func event(_ type: NSEvent.EventType, at point: CGPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                               windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        view.mouseDown(with: event(.leftMouseDown, at: start))
        view.mouseDragged(with: event(.leftMouseDragged, at: end))
        view.mouseUp(with: event(.leftMouseUp, at: end))
    }

    private func confirm(_ view: AreaSelectionView) {
        view.keyDown(with: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: "\r",
            charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!)
    }
}

@MainActor
private final class SelectionObserver: AreaSelectionViewDelegate {
    var rect: CGRect?
    func areaSelectionView(_ view: AreaSelectionView, didConfirmSelection rect: CGRect, on screen: NSScreen) { self.rect = rect }
    func areaSelectionViewDidCancel(_ view: AreaSelectionView) {}
    func areaSelectionViewDidBeginDrawing(_ view: AreaSelectionView) {}
    func areaSelectionView(_ view: AreaSelectionView, didSelectWindow window: SCWindow) {}
}
