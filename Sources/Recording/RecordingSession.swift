import AppKit
import Observation
import ScreenCaptureKit

/// Owns the capture and encoding lifecycle. Selection UI belongs to the caller.
@MainActor
@Observable
package final class RecordingSession: CaptureEngineDelegate {
    package private(set) var state: RecordingState = .idle
    package var onFinished: ((URL) -> Void)?
    package var onError: ((Error) -> Void)?

    private let engine = CaptureEngine()
    private let writer = AssetWriter()

    package init() {
        engine.delegate = self
        engine.sampleBufferDelegate = writer
    }

    package func start(
        filter: SCContentFilter,
        sourceRect: CGRect? = nil,
        configuration: RecordingConfiguration,
        outputURL: URL
    ) async throws {
        guard state == .idle else { throw CaptureError.captureAlreadyRunning }
        state = .starting

        do {
            let size = try videoSize(filter: filter, sourceRect: sourceRect)
            try writer.setup(url: outputURL, settings: configuration, videoSize: size)
            try writer.startWriting()
            try await engine.startCapture(
                filter: filter, configuration: configuration, videoSize: size, sourceRect: sourceRect
            )
            state = .recording
        } catch {
            try? await engine.stopCapture()
            writer.cancel()
            state = .idle
            throw error
        }
    }

    @discardableResult
    package func stop() async throws -> URL {
        guard state.isRecording else { throw CaptureError.notRecording }
        state = .stopping
        defer { state = .idle }
        let endTime = CMClockGetTime(CMClockGetHostTimeClock())

        // Finish the file even if the capture stream has already failed.
        do { try await engine.stopCapture() } catch { onError?(error) }

        do {
            let result = try await writer.finishWriting(at: endTime)
            guard result.videoFrameCount > 0 else { throw AssetWriterError.noFramesWritten }
            onFinished?(result.url)
            return result.url
        } catch {
            // finishWriting clears outputURL on success, preserving an audio-only file.
            writer.cancel()
            throw error
        }
    }

    package func togglePause() {
        if state == .recording {
            writer.pause()
            state = .paused
        } else if state == .paused {
            writer.resume()
            state = .recording
        }
    }

    private func videoSize(filter: SCContentFilter, sourceRect: CGRect?) throws -> CGSize {
        var scale = CGFloat(filter.pointPixelScale)
        if sourceRect == nil, filter.style == .window, let window = filter.includedWindows.first {
            let displays = NSScreen.screens.compactMap { screen -> DisplayGeometry? in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                    return nil
                }
                return DisplayGeometry(frame: CGDisplayBounds(id), scaleFactor: screen.backingScaleFactor)
            }
            scale = CaptureSizeCalculator.windowScale(windowFrame: window.frame, displays: displays, fallback: scale)
        }
        let size = CaptureSizeCalculator.videoSize(
            contentRect: sourceRect ?? filter.contentRect, scale: scale, useNativeResolution: true
        )
        guard size.width > 0, size.height > 0 else { throw CaptureError.invalidVideoSize }
        return CGSize(width: ceil(size.width / 2) * 2, height: ceil(size.height / 2) * 2)
    }

    func captureEngine(_ engine: CaptureEngine, didStopWithError error: Error?) {
        guard state.isRecording else { return }
        Task {
            do { try await stop() } catch { onError?(error) }
        }
        if let error, (error as? SCStreamError)?.code != .userStopped { onError?(error) }
    }

    func captureEngine(_ engine: CaptureEngine, systemAudioDidFailWith error: Error?) {
        if let error { onError?(error) }
    }
}
