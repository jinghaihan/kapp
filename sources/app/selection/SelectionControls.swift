import Observation

@MainActor
@Observable
final class SelectionControls {
    var width = 0
    var height = 0
    var advanced = false
    var ratioLocked = false
    var isFullScreen = false
}
