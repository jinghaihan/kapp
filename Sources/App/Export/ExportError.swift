import Foundation

enum ExportError: LocalizedError {
    case invalidRange
    case missingVideo
    case cannotExport
    case replacesOriginal
    case clipboardFailed

    var errorDescription: String? {
        switch self {
        case .invalidRange: "Choose a non-empty range within the recording."
        case .missingVideo: "The recording has no readable video track."
        case .cannotExport: "This recording could not be prepared for export."
        case .replacesOriginal: "Choose a different filename to keep the original recording."
        case .clipboardFailed: "The exported recording could not be copied to the clipboard."
        }
    }
}
