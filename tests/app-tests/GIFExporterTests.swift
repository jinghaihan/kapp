import AppKit
import AVFoundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Kapp

@MainActor
@Suite(.serialized)
struct GIFExporterTests {
    @Test func respectsTheRequestedSizeAndFrameRate() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try await RecordingFixture.make(in: directory)
        let destination = directory.appending(path: "scaled.gif")
        try await GIFExporter.export(source: source, range: ClipRange(start: 0, end: 0.5),
            settings: VideoExportSettings(width: 32, height: 24, frameRate: 10), to: destination)
        let imageSource = try #require(CGImageSourceCreateWithURL(destination as CFURL, nil))
        #expect(CGImageSourceGetCount(imageSource) == 5)
        let frame = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        #expect(frame.width == 32 && frame.height == 24)
    }

    @Test func exportsAnimatedTrimmedGIFWithAccurateTiming() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try await RecordingFixture.make(in: directory)
        let destination = directory.appending(path: "clip.gif")
        try await GIFExporter.export(source: source, range: ClipRange(start: 1.2, end: 1.7), to: destination)
        let gif = try #require(CGImageSourceCreateWithURL(destination as CFURL, nil))
        #expect(CGImageSourceGetType(gif) as String? == UTType.gif.identifier)
        let count = CGImageSourceGetCount(gif)
        #expect(count == 8)
        var duration = 0.0
        for index in 0..<count {
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(gif, index, nil) as? [String: Any])
            let timing = try #require(properties[kCGImagePropertyGIFDictionary as String] as? [String: Any])
            duration += try #require(timing[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double)
        }
        #expect(abs(duration - 0.5) < 0.011)
        let first = try #require(CGImageSourceCreateImageAtIndex(gif, 0, nil))
        #expect(first.width == 64 && first.height == 48)

        let item = try RecordingClipboard.item(for: destination, format: .gif)
        #expect(item.string(forType: .fileURL) == destination.absoluteString)
        let data = try Data(contentsOf: destination)
        #expect(item.data(forType: NSPasteboard.PasteboardType(UTType.gif.identifier)) == data)
    }

    @Test func cancelledGIFExportDoesNotCreateAnOutputFile() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try await RecordingFixture.make(in: directory)
        let destination = directory.appending(path: "cancelled.gif")
        let task = Task {
            try await GIFExporter.export(source: source, range: ClipRange(start: 0, end: 2), to: destination)
        }
        task.cancel()
        do {
            try await task.value
            Issue.record("A cancelled GIF export should fail.")
        } catch {}
        #expect(!FileManager.default.fileExists(atPath: destination.path()))
    }
}
