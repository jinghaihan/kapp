import AVFoundation
import ScreenCaptureKit
import Testing
@testable import KappRecording

/// A two-second recording: red, then blue, with separate system and microphone tracks.
@MainActor
enum RecordingFixture {
    static func make(in directory: URL) async throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "source.mp4")
        var configuration = RecordingConfiguration()
        configuration.frameRate = 30
        configuration.captureSystemAudio = true
        configuration.captureMicrophone = true
        let writer = AssetWriter()
        try writer.setup(url: url, settings: configuration, videoSize: CGSize(width: 64, height: 48))
        try writer.startWriting()
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
        for index in 0..<60 {
            let time = CMTime(value: CMTimeValue(index), timescale: 30)
            writer.appendVideoSample(try frame(at: time, blue: index >= 30))
            let audio = try #require(SilentAudioBuffer.make(
                matching: format.formatDescription, duration: CMTime(value: 1600, timescale: 48000), at: time
            ))
            writer.appendAudioSample(audio)
            writer.appendMicrophoneSample(audio)
            try await Task.sleep(for: .milliseconds(2))
        }
        let result = try await writer.finishWriting().url
        return result
    }

    private static func frame(at time: CMTime, blue: Bool) throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        #expect(CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA,
                                  [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
                                  &pixelBuffer) == kCVReturnSuccess)
        let image = try #require(pixelBuffer)
        CVPixelBufferLockBaseAddress(image, [])
        let pointer = try #require(CVPixelBufferGetBaseAddress(image))
        pointer.assumingMemoryBound(to: UInt32.self).initialize(
            repeating: blue ? 0xFF0000FF : 0xFFFF0000, count: CVPixelBufferGetDataSize(image) / 4
        )
        CVPixelBufferUnlockBaseAddress(image, [])
        var format: CMVideoFormatDescription?
        #expect(CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                           imageBuffer: image, formatDescriptionOut: &format) == noErr)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                       presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        #expect(CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: image,
                                                       formatDescription: try #require(format), sampleTiming: &timing,
                                                       sampleBufferOut: &sample) == noErr)
        let buffer = try #require(sample)
        let attachments = try #require(CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as? [NSMutableDictionary])
        try #require(attachments.first)[SCStreamFrameInfo.status.rawValue] = SCFrameStatus.complete.rawValue
        return buffer
    }
}
