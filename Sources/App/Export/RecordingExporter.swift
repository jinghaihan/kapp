@preconcurrency import AVFoundation
import Foundation

enum RecordingExporter {
    @concurrent
    static func exportMP4(source: URL, range: ClipRange, muted: Bool, to destination: URL) async throws {
        guard source.resolvingSymlinksInPath().standardizedFileURL != destination.resolvingSymlinksInPath().standardizedFileURL else {
            throw ExportError.replacesOriginal
        }
        let asset = AVURLAsset(url: source)
        try range.validate(duration: try await asset.load(.duration).seconds)
        let composition = AVMutableComposition()
        guard let video = try await asset.loadTracks(withMediaType: .video).first,
              let outputVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.missingVideo
        }
        try outputVideo.insertTimeRange(range.timeRange, of: video, at: .zero)
        outputVideo.preferredTransform = try await video.load(.preferredTransform)

        var audioParameters: [AVAudioMixInputParameters] = []
        if !muted {
            for audio in try await asset.loadTracks(withMediaType: .audio) {
                guard let output = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    throw ExportError.cannotExport
                }
                // A microphone can stop before the video. Insert only its overlapping samples.
                let available = try await audio.load(.timeRange).intersection(range.timeRange)
                guard available.duration > .zero else { continue }
                try output.insertTimeRange(available, of: audio, at: available.start - range.timeRange.start)
                let parameters = AVMutableAudioMixInputParameters(track: output)
                parameters.setVolume(1, at: .zero)
                audioParameters.append(parameters)
            }
        }
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.cannotExport
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = audioParameters
        session.audioMix = mix
        session.shouldOptimizeForNetworkUse = true
        do {
            try Task.checkCancellation()
            try await session.export(to: destination, as: .mp4)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}
