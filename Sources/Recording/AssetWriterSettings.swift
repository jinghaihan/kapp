// Adapted from BetterCapture by Joshua Sattler and contributors. MIT; see LICENSE.
import AVFoundation

enum AssetWriterSettings {
    static func video(from settings: RecordingConfiguration, size: CGSize) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(size.width * size.height * 0.1 * Double(settings.frameRate)),
                AVVideoExpectedSourceFrameRateKey: settings.frameRate,
                AVVideoMaxKeyFrameIntervalKey: settings.frameRate * 2
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        ]
    }

    static func audio(from settings: RecordingConfiguration) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 256000
        ]
    }
}
