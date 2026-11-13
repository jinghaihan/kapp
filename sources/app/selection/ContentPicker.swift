// Adapted from BetterCapture's CaptureEngine picker integration. MIT; see LICENSE.
@preconcurrency import ScreenCaptureKit

@MainActor
final class ContentPicker: NSObject, SCContentSharingPickerObserver {
    private let picker = SCContentSharingPicker.shared
    private var continuation: CheckedContinuation<SCContentFilter?, Error>?

    override init() {
        super.init()
        picker.add(self)
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleDisplay, .singleWindow]
        configuration.allowsChangingSelectedContent = false
        if let bundleID = Bundle.main.bundleIdentifier {
            configuration.excludedBundleIDs = [bundleID]
        }
        picker.defaultConfiguration = configuration
    }

    func present() async throws -> SCContentFilter? {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            picker.isActive = true
            picker.present()
        }
    }

    nonisolated func contentSharingPicker(
        _ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?
    ) {
        Task { @MainActor in
            self.picker.isActive = false
            self.continuation?.resume(returning: filter)
            self.continuation = nil
        }
    }

    func cancel() {
        picker.isActive = false
        continuation?.resume(returning: nil)
        continuation = nil
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in
            self.picker.isActive = false
            self.continuation?.resume(returning: nil)
            self.continuation = nil
        }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in
            self.picker.isActive = false
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }
}
