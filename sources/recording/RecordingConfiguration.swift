import Foundation

/// Per-recording options, independent of persistence and application UI.
package struct RecordingConfiguration: Sendable {
    package var frameRate: Int = 60
    package var captureSystemAudio = false
    package var captureMicrophone = false
    package var showCursor = true

    package init() {}
}
