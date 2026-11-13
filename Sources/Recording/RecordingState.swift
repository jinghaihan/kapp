package enum RecordingState: Equatable {
    case idle
    case starting
    case recording
    case paused
    case stopping

    package var isRecording: Bool {
        self == .recording || self == .paused
    }
}
