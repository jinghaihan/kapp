// Adapted from BetterCapture's ContentFilterService. MIT; see LICENSE.
import AVFoundation
import CoreGraphics
@preconcurrency import ScreenCaptureKit

@MainActor
final class CapturePermissions {
    func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func hasMicrophonePermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        default: false
        }
    }

    func isSelectedDisplayConnected(_ filter: SCContentFilter) async -> Bool {
        guard filter.style == .display,
              let displayID = filter.includedDisplays.first?.displayID else { return true }
        guard let content = try? await SCShareableContent.current else { return true }
        return content.displays.contains { $0.displayID == displayID }
    }
}
