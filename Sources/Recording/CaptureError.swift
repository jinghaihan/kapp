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
            "The capture stream could not be created."
        case .captureAlreadyRunning:
            "A recording is already in progress."
        case .screenRecordingPermissionDenied:
            "Allow Kapp in System Settings → Privacy & Security → Screen Recording, then reopen Kapp."
        case .microphonePermissionDenied:
            "Allow Kapp in System Settings → Privacy & Security → Microphone."
        case .selectedDisplayDisconnected:
            "The selected display is disconnected. Select the recording area again."
        case .invalidVideoSize:
            "The selected content has no valid recording dimensions. Select it again."
        case .notRecording:
            "There is no active recording to stop."
        }
    }
}
