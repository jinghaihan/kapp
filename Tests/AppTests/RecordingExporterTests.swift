import AVFoundation
import Testing
@testable import Kapp

@MainActor
@Suite(.serialized)
struct RecordingExporterTests {
    @Test func exportsOnlyTheSelectedVideoAndMixesBothAudioTracks() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try await RecordingFixture.make(in: directory)
        let sourceAsset = AVURLAsset(url: source)
        #expect(try await sourceAsset.loadTracks(withMediaType: .audio).count == 2)
        let destination = directory.appending(path: "trimmed.mp4")
        try await RecordingExporter.exportMP4(source: source, range: ClipRange(start: 1.2, end: 1.7),
                                             muted: false, to: destination)
        let result = AVURLAsset(url: destination)
        #expect(abs(try await result.load(.duration).seconds - 0.5) < 0.04)
        #expect(try await result.loadTracks(withMediaType: .audio).count == 1)

        let frame = try await AVAssetImageGenerator(asset: result).image(at: .zero).image
        let context = try #require(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                                            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(frame, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let pixel = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        #expect(pixel[2] > 200 && pixel[0] < 50, "The selected interval must contain the blue half, not the red beginning.")
    }

    @Test func mutedExportRemovesAudioAndKeepsTheOriginal() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try await RecordingFixture.make(in: directory)
        let original = try Data(contentsOf: source)
        let destination = directory.appending(path: "muted.mp4")
        try await RecordingExporter.exportMP4(source: source, range: ClipRange(start: 0.2, end: 0.7),
                                             muted: true, to: destination)
        #expect(try await AVURLAsset(url: destination).loadTracks(withMediaType: .audio).isEmpty)
        #expect(try Data(contentsOf: source) == original)
        await #expect(throws: ExportError.self) {
            try await RecordingExporter.exportMP4(source: source, range: ClipRange(start: 0, end: 1), muted: true, to: source)
        }
        #expect(try Data(contentsOf: source) == original)
    }

    @Test func cancellingExportDoesNotLeaveAnOutputFile() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try await RecordingFixture.make(in: directory)
        let destination = directory.appending(path: "cancelled.mp4")
        let task = Task {
            try await RecordingExporter.exportMP4(source: source, range: ClipRange(start: 0, end: 2),
                                                 muted: false, to: destination)
        }
        task.cancel()
        do {
            try await task.value
            Issue.record("A cancelled export should fail.")
        } catch {}
        #expect(!FileManager.default.fileExists(atPath: destination.path()))
    }
}
