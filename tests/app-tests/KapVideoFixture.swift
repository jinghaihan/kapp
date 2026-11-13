@preconcurrency import AVFoundation
import Testing
@testable import KappRecording

/// Synthetic equivalents of Kap's portrait Retina input with audio and silent
/// landscape input. Keep its output-size expectations/ranges without committing 21MB
/// of media fixtures or requiring a network connection to run tests.
@MainActor
enum KapVideoFixture {
    static func make(in directory: URL, retina: Bool) async throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "input.mp4")
        let width = retina ? 938 : 510
        let height = retina ? 1678 : 286
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoExpectedSourceFrameRateKey: 5, AVVideoMaxKeyFrameIntervalKey: 5]
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: nil)
        writer.add(video)
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2
        ], sourceFormatHint: format.formatDescription)
        if retina { writer.add(audio) }
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var buffer: CVPixelBuffer?
        #expect(CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer) == kCVReturnSuccess)
        let frame = try #require(buffer)
        CVPixelBufferLockBaseAddress(frame, [])
        let pixels = try #require(CVPixelBufferGetBaseAddress(frame)).assumingMemoryBound(to: UInt32.self)
        pixels.initialize(repeating: 0xFF2266CC, count: CVPixelBufferGetDataSize(frame) / 4)
        CVPixelBufferUnlockBaseAddress(frame, [])
        // Feed the tracks independently. Waiting for video before supplying more
        // audio can stall AVAssetWriter's interleaver under concurrent codec load.
        let videoTask = Task { @MainActor in
            for index in 0..<240 {
                while !video.isReadyForMoreMediaData {
                    if let error = writer.error { throw error }
                    try await Task.sleep(for: .milliseconds(1))
                }
                #expect(adaptor.append(frame, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: 5)))
            }
            video.markAsFinished()
        }
        let audioTask = Task { @MainActor in
            guard retina else { return }
            for index in 0..<240 {
                while !audio.isReadyForMoreMediaData {
                    if let error = writer.error { throw error }
                    try await Task.sleep(for: .milliseconds(1))
                }
                let time = CMTime(value: CMTimeValue(index), timescale: 5)
                let sample = try #require(SilentAudioBuffer.make(matching: format.formatDescription,
                    duration: CMTime(value: 1, timescale: 5), at: time))
                #expect(audio.append(sample))
            }
            audio.markAsFinished()
        }
        do {
            try await withTaskCancellationHandler {
                try await videoTask.value
                try await audioTask.value
            } onCancel: {
                videoTask.cancel()
                audioTask.cancel()
            }
        } catch {
            videoTask.cancel()
            audioTask.cancel()
            writer.cancelWriting()
            throw error
        }
        writer.endSession(atSourceTime: CMTime(value: 48, timescale: 1))
        await withCheckedContinuation { continuation in writer.finishWriting { continuation.resume() } }
        if let error = writer.error { throw error }
        return url
    }
}
