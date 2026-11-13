// Metadata assertions ported from wulkano/Kap, test/convert.ts (MIT).
// Covers the MP4/GIF formats implemented here. Fixtures are synthesized locally;
// Electron plugins, progress callbacks and other codecs are outside this suite.
import AVFoundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Kapp

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct KapConversionTests {
    @Test("Kap: mp4 retina with sound") func retinaMP4WithSound() async throws {
        try await checkMP4(retina: true, width: 469, height: 839, fps: 39,
                           start: 30, end: 43.5, muted: false, expected: CGSize(width: 470, height: 840))
    }

    @Test("Kap: mp4 retina without sound") func retinaMP4WithoutSound() async throws {
        try await checkMP4(retina: true, width: 46, height: 83, fps: 10,
                           start: 0, end: 5, muted: true, expected: CGSize(width: 46, height: 84))
    }

    @Test("Kap: mp4 non-retina odd dimensions") func nonRetinaMP4() async throws {
        try await checkMP4(retina: false, width: 255, height: 143, fps: 30,
                           start: 11.5, end: 27, muted: false, expected: CGSize(width: 256, height: 144))
    }

    @Test("Kap: gif retina") func retinaGIF() async throws {
        try await checkGIF(retina: true, width: 236, height: 420, fps: 10, start: 0, end: 8.5)
    }

    @Test("Kap: gif non-retina preserves odd dimensions") func nonRetinaGIF() async throws {
        try await checkGIF(retina: false, width: 255, height: 143, fps: 15, start: 11.5, end: 27)
    }

    private func checkMP4(retina: Bool, width: Int, height: Int, fps: Int,
                          start: Double, end: Double, muted: Bool, expected: CGSize) async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try await KapVideoFixture.make(in: directory, retina: retina)
        let output = directory.appending(path: "output.mp4")
        try await RecordingExporter.exportMP4(source: source, range: ClipRange(start: start, end: end),
            muted: muted, settings: VideoExportSettings(width: width, height: height, frameRate: fps), to: output)
        let asset = AVURLAsset(url: output)
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await video.load(.naturalSize) == expected)
        #expect(abs(try await video.load(.nominalFrameRate) - Float(fps)) < 0.01)
        #expect(abs(try await asset.load(.duration).seconds - (end - start)) <= 0.5)
        let formats = try await video.load(.formatDescriptions)
        #expect(CMFormatDescriptionGetMediaSubType(try #require(formats.first)) == kCMVideoCodecType_H264)
        #expect(try await asset.loadTracks(withMediaType: .audio).isEmpty == (muted || !retina))
    }

    private func checkGIF(retina: Bool, width: Int, height: Int, fps: Int, start: Double, end: Double) async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try await KapVideoFixture.make(in: directory, retina: retina)
        let output = directory.appending(path: "output.gif")
        try await GIFExporter.export(source: source, range: ClipRange(start: start, end: end),
            settings: VideoExportSettings(width: width, height: height, frameRate: fps), to: output)
        let imageSource = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        #expect(CGImageSourceGetType(imageSource) as String? == UTType.gif.identifier)
        let frame = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        #expect(frame.width == width && frame.height == height)
        #expect(CGImageSourceGetCount(imageSource) == Int(ceil((end - start) * Double(fps))))
        var duration = 0.0
        for index in 0..<CGImageSourceGetCount(imageSource) {
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [String: Any])
            let timing = try #require(properties[kCGImagePropertyGIFDictionary as String] as? [String: Any])
            duration += try #require(timing[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double)
        }
        #expect(abs(duration - (end - start)) <= 0.5)
    }
}
