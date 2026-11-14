import KappLocalization
import Foundation

enum ExportError: LocalizedError {
    case invalidRange
    case missingVideo
    case cannotExport
    case replacesOriginal
    case clipboardFailed
    case cannotEncodeGIF
    case invalidSettings

    var errorDescription: String? {
        switch self {
        case .invalidRange: tr("Choose a non-empty range within the recording.")
        case .missingVideo: tr("The recording has no readable video track.")
        case .cannotExport: tr("This recording could not be prepared for export.")
        case .replacesOriginal: tr("Choose a different filename to keep the original recording.")
        case .clipboardFailed: tr("The exported recording could not be copied to the clipboard.")
        case .cannotEncodeGIF: tr("The animated GIF could not be encoded. Try exporting as MP4.")
        case .invalidSettings: tr("Choose a valid output size and frame rate.")
        }
    }
}
