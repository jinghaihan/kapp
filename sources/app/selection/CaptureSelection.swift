import AppKit
@preconcurrency import ScreenCaptureKit

@MainActor
struct CaptureSelection {
    let filter: SCContentFilter
    let sourceRect: CGRect?
    let screenRect: CGRect?
    let label: String

    init(filter: SCContentFilter) {
        self.filter = filter
        sourceRect = nil
        screenRect = nil
        label = filter.includedWindows.first?.title ?? "Screen"
    }

    init(area: AreaSelectionResult) async throws {
        let content = try await SCShareableContent.current
        let id = area.screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        guard let display = content.displays.first(where: { $0.displayID == id }) else {
            throw SelectionError.displayDisconnected
        }
        let apps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        filter = SCContentFilter(display: display, excludingApplications: apps, exceptingWindows: [])
        sourceRect = SelectionGeometry.sourceRect(
            for: area.screenRect, on: area.screen.frame, scale: area.screen.backingScaleFactor
        )
        screenRect = area.screenRect
        label = "Selected area"
    }
}
