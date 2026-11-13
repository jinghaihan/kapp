import AVFoundation
import Testing
@testable import Kapp

@MainActor
struct TrimRangeTests {
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
