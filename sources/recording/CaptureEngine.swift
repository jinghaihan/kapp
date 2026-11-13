//
//  CaptureEngine.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import Foundation
@preconcurrency import ScreenCaptureKit
import OSLog

/// Delegate protocol for receiving capture events (non-sample buffer events)
@MainActor
protocol CaptureEngineDelegate: AnyObject {
    func captureEngine(_ engine: CaptureEngine, didStopWithError error: Error?)
    func captureEngine(_ engine: CaptureEngine, systemAudioDidFailWith error: Error?)
}

/// Protocol for receiving sample buffers - called synchronously on capture queue
protocol CaptureEngineSampleBufferDelegate: AnyObject, Sendable {
    nonisolated func captureEngine(_ engine: CaptureEngine, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer)
    nonisolated func captureEngine(_ engine: CaptureEngine, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer)
    nonisolated func captureEngine(_ engine: CaptureEngine, didOutputMicrophoneSampleBuffer sampleBuffer: CMSampleBuffer)
}

/// Service responsible for managing ScreenCaptureKit capture streams
@MainActor
final class CaptureEngine: NSObject {

    // MARK: - Properties

    weak var delegate: CaptureEngineDelegate?

    /// Sample buffer delegate - accessed from capture queue, hence nonisolated
    /// The delegate must be set before starting capture and not changed during capture
    nonisolated(unsafe) weak var sampleBufferDelegate: CaptureEngineSampleBufferDelegate?

    private(set) var isCapturing = false

    private var stream: SCStream?
    private let systemAudioStream = SystemAudioStream()
    private let permissions = CapturePermissions()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kapp", category: "CaptureEngine")

    // Queues for sample buffer handling
    private let videoSampleQueue = DispatchQueue(label: "app.kapp.videoSampleQueue", qos: .userInteractive)
    private let audioSampleQueue = DispatchQueue(label: "app.kapp.audioSampleQueue", qos: .userInteractive)
    private let microphoneSampleQueue = DispatchQueue(label: "app.kapp.microphoneSampleQueue", qos: .userInteractive)

    // MARK: - Stream Management

    /// Starts capturing the content chosen by the caller
    /// - Parameters:
    ///   - settings: The capture configuration for this recording
    ///   - videoSize: The dimensions for the captured video
    ///   - sourceRect: Optional rectangle for area selection (display points, top-left origin)
    func startCapture(filter: SCContentFilter, configuration settings: RecordingConfiguration, videoSize: CGSize, sourceRect: CGRect? = nil) async throws {

        try await verifyPermissions(for: settings)

        // A display selected before it was disconnected still yields a usable filter, but the
        // stream never delivers frames. Fail fast instead of recording without a video track.
        guard await permissions.isSelectedDisplayConnected(filter) else {
            throw CaptureError.selectedDisplayDisconnected
        }

        let isWindowCapture = filter.style == .window
        let needsDedicatedAudioStream = settings.captureSystemAudio && filter.style != .display

        let streamConfig = createStreamConfiguration(
            from: settings,
            contentSize: videoSize,
            sourceRect: sourceRect,
            isWindowCapture: isWindowCapture,
            capturesAudio: settings.captureSystemAudio && !needsDedicatedAudioStream
        )

        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)

        guard let stream else {
            throw CaptureError.failedToCreateStream
        }

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoSampleQueue)
        logger.info("Added screen output")

        if settings.captureSystemAudio && !needsDedicatedAudioStream {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioSampleQueue)
            logger.info("Added system audio output")
        }

        // The microphone is device-scoped rather than filter-scoped, so it always stays on
        // the main stream.
        if settings.captureMicrophone {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: microphoneSampleQueue)
            logger.info("Added microphone output (default device)")
        }

        logger.info("Stream config - capturesAudio: \(settings.captureSystemAudio), captureMicrophone: \(settings.captureMicrophone)")
        logger.info("Starting stream capture...")
        try await stream.startCapture()
        logger.info("Stream capture started successfully")
        isCapturing = true

        if needsDedicatedAudioStream {
            await startSystemAudioStream()
        }

        logger.info("Capture started successfully")
    }

    /// Ensures the permissions the requested capture needs are granted, prompting if they are not
    /// - Parameter settings: The capture configuration for this recording
    private func verifyPermissions(for settings: RecordingConfiguration) async throws {
        let hasPermission = permissions.hasScreenRecordingPermission()
        logger.info("Screen recording permission check: \(hasPermission)")

        guard hasPermission else {
            // Request permission - this will open the system prompt or System Settings
            permissions.requestScreenRecordingPermission()
            throw CaptureError.screenRecordingPermissionDenied
        }

        guard settings.captureMicrophone else { return }

        let hasMicPermission = permissions.hasMicrophonePermission()
        logger.info("Microphone permission check: \(hasMicPermission)")

        if !hasMicPermission, await !permissions.requestMicrophonePermission() {
            throw CaptureError.microphonePermissionDenied
        }
    }

    /// Starts the dedicated system audio stream, keeping the recording alive if it fails
    private func startSystemAudioStream() async {
        do {
            try await systemAudioStream.start(output: self, delegate: self, sampleQueue: audioSampleQueue)
        } catch {
            logger.error("Failed to start system audio stream: \(error.localizedDescription)")
            delegate?.captureEngine(self, systemAudioDidFailWith: error)
        }
    }

    /// Stops the current capture stream
    func stopCapture() async throws {
        await systemAudioStream.stop()

        guard let runningStream = stream else { return }

        // Detach before suspending, so a second caller cannot stop the same stream again
        stream = nil
        isCapturing = false

        do {
            try await runningStream.stopCapture()
        } catch let error as NSError where error.code == SCStreamError.Code.attemptToStopStreamState.rawValue {
            // The stream had already stopped on its own, which is what was wanted
            logger.debug("Stream was already stopped")
        }

        logger.info("Capture stopped successfully")
    }

    // MARK: - Configuration

    /// Creates an SCStreamConfiguration from user settings
    /// - Parameters:
    ///   - settings: The capture configuration for this recording
    ///   - contentSize: The output dimensions for the captured video
    ///   - sourceRect: Optional rectangle for area selection (display points, top-left origin)
    ///   - isWindowCapture: Whether the filter captures a single window
    ///   - capturesAudio: Whether this stream carries system audio, or a dedicated one does
    private func createStreamConfiguration(
        from settings: RecordingConfiguration,
        contentSize: CGSize,
        sourceRect: CGRect? = nil,
        isWindowCapture: Bool = false,
        capturesAudio: Bool = false
    ) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.captureDynamicRange = .SDR

        // Set output dimensions - required for proper capture
        config.width = Int(contentSize.width)
        config.height = Int(contentSize.height)

        // Independent window capture is the one mode where ScreenCaptureKit does not resize content
        // to the configured dimensions on its own: it renders the window at its natural pixel size
        // in the top-left corner and leaves the rest of the buffer blank. Scaling to fit keeps the
        // content filling the frame even if the dimensions above are ever wrong again, rather than
        // silently baking a crop into the recording.
        if isWindowCapture {
            config.scalesToFit = true
        }

        // Set source rect for area selection (only works with display captures)
        if let sourceRect {
            config.sourceRect = sourceRect
            logger.info("Source rect set: \(sourceRect.origin.x),\(sourceRect.origin.y) \(sourceRect.width)x\(sourceRect.height)")
        }

        // Keep capture timestamps on the same grid as the file writer.
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.frameRate))

        // AssetWriter holds on to the two most recent frames so it can repeat the last
        // one across a stall. The default queue depth of 3 would leave ScreenCaptureKit
        // just one spare buffer, so give it more headroom.
        config.queueDepth = 8

        // Cursor visibility
        config.showsCursor = settings.showCursor

        // Window shadows
        config.ignoreShadowsDisplay = false
        config.ignoreShadowsSingleWindow = false

        // System audio settings
        config.excludesCurrentProcessAudio = true
        config.capturesAudio = capturesAudio
        config.sampleRate = 48000
        config.channelCount = 2

        // Microphone settings - requires full TCC screen recording permission
        config.captureMicrophone = settings.captureMicrophone

        return config
    }

}

// MARK: - SCStreamDelegate

extension CaptureEngine: SCStreamDelegate {

    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        // Resolve the identity here: SCStream is not Sendable and cannot cross to the main actor.
        let isSystemAudioStream = systemAudioStream.owns(stream)
        let stoppedStreamID = ObjectIdentifier(stream)

        Task { @MainActor in
            guard !isSystemAudioStream else {
                // Losing system audio must not tear down the video recording
                self.systemAudioStream.handleStoppedExternally()
                self.delegate?.captureEngine(self, systemAudioDidFailWith: error)
                logger.error("System audio stream stopped with error: \(error.localizedDescription)")
                return
            }

            guard let currentStream = self.stream,
                  ObjectIdentifier(currentStream) == stoppedStreamID else { return }

            self.isCapturing = false
            self.stream = nil
            await self.systemAudioStream.stop()
            self.delegate?.captureEngine(self, didStopWithError: error)
            logger.error("Stream stopped with error: \(error.localizedDescription)")
        }
    }

}

// MARK: - SCStreamOutput

extension CaptureEngine: SCStreamOutput {

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        // Call sample buffer delegate synchronously on the capture queue
        // to ensure the buffer remains valid during processing
        switch type {
        case .screen:
            sampleBufferDelegate?.captureEngine(self, didOutputVideoSampleBuffer: sampleBuffer)
        case .audio:
            sampleBufferDelegate?.captureEngine(self, didOutputAudioSampleBuffer: sampleBuffer)
        case .microphone:
            sampleBufferDelegate?.captureEngine(self, didOutputMicrophoneSampleBuffer: sampleBuffer)
        @unknown default:
            break
        }
    }
}

