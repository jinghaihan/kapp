import KappLocalization
import Foundation

enum CaptureError: LocalizedError {
    case failedToCreateStream
    case captureAlreadyRunning
    case screenRecordingPermissionDenied
    case microphonePermissionDenied
    case selectedDisplayDisconnected
    case invalidVideoSize
    case notRecording

    var errorDescription: String? {
        switch self {
        case .failedToCreateStream:
            tr("The capture stream could not be created.")
        case .captureAlreadyRunning:
            tr("A recording is already in progress.")
        case .screenRecordingPermissionDenied:
            tr("Allow Kapp in System Settings → Privacy & Security → Screen Recording, then reopen Kapp.")
        case .microphonePermissionDenied:
            tr("Allow Kapp in System Settings → Privacy & Security → Microphone.")
        case .selectedDisplayDisconnected:
            tr("The selected display is disconnected. Select the recording area again.")
        case .invalidVideoSize:
            tr("The selected content has no valid recording dimensions. Select it again.")
        case .notRecording:
            tr("There is no active recording to stop.")
        }
    }
}
