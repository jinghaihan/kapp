import AVFoundation
import AppKit
import Testing
@testable import Kapp

@MainActor
struct TrimRangeTests {
    @Test func trackClicksSeekWithinTheSelectedRangeWithoutStartingPlayback() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = EditorModel(source: try await RecordingFixture.make(in: directory))
        defer { model.close() }
        await model.load(autoPlay: false)
        model.updateTrim(start: 0.2)
        model.updateTrim(end: 0.7)
        let control = TrimRangeControl(frame: CGRect(x: 0, y: 0, width: 400, height: 32))
        control.model = model
        control.duration = model.fullDuration
        control.range = model.range
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: CGPoint(x: 200, y: 16),
                modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1))
            if type == .leftMouseDown { control.mouseDown(with: event) }
            else { control.mouseUp(with: event) }
        }
        #expect(abs(model.currentTime - 0.45) < 0.001)
        #expect(!model.isPlaying)
    }

    @Test func endpointsImmediatelyUpdateTheExportAndPlaybackBounds() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try await RecordingFixture.make(in: directory)
        let model = EditorModel(source: source)
        defer { model.close() }
        await model.load(autoPlay: false)
        model.beginDragging()
        model.updateTrim(start: 0.5)
        model.updateTrim(end: 1.5)
        model.endDragging()
        #expect(model.isPlaying, "Kap resumes playback when a trim handle is released.")
        let range = try #require(model.range)
        #expect(range.start == 0.5 && range.end == 1.5)
        #expect(model.canExport)
        #expect(model.player.currentItem?.reversePlaybackEndTime.seconds == 0.5)
        #expect(model.player.currentItem?.forwardPlaybackEndTime.seconds == 1.5)
        model.updateTrim(start: 10)
        #expect(try #require(model.range).start < 1.5)
        model.updateTrim(end: -1)
        let clamped = try #require(model.range)
        #expect(clamped.end > clamped.start)
    }

    @Test func geometryMapsBothEndpointsWithoutClippingTheHandles() {
        #expect(TrimGeometry.position(for: 0, duration: 10, width: 400) == 2.5)
        #expect(TrimGeometry.position(for: 10, duration: 10, width: 400) == 397.5)
        #expect(TrimGeometry.time(at: -20, duration: 10, width: 400) == 0)
        #expect(TrimGeometry.time(at: 500, duration: 10, width: 400) == 10)
        for time in [0.0, 0.5, 2, 7.3, 10] {
            let position = TrimGeometry.position(for: time, duration: 10, width: 400)
            #expect(abs(TrimGeometry.time(at: position, duration: 10, width: 400) - time) < 0.000001)
        }
    }
}
