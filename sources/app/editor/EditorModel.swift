import AppKit
@preconcurrency import AVFoundation
import AVKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class EditorModel {
    let source: URL
    private let settings: AppSettings
    let player: AVPlayer
    private(set) var range: ClipRange?
    private(set) var isExporting = false
    private(set) var copied = false
    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false
    private(set) var sourceSize = CGSize.zero
    private(set) var originalFrameRate = 60
    private(set) var outputWidth = 0
    private(set) var outputHeight = 0
    private(set) var frameRate = 60
    private(set) var hoverTime: Double?
    private(set) var thumbnail: NSImage?
    private(set) var hoverFraction = 0.0
    private(set) var isResizingRange = false
    var format: ExportFormat = .mp4 {
        didSet {
            player.isMuted = muted || format == .gif
            copied = false
            if originalFrameRate > 0 {
                frameRate = min(maximumFrameRate, savedFrameRate)
            }
        }
    }
    var muted = false {
        didSet {
            player.isMuted = muted || format == .gif
            copied = false
        }
    }
    var errorMessage: String?

    @ObservationIgnored weak var playerView: AVPlayerView?
    @ObservationIgnored private var exportTask: Task<Void, Never>?
    private(set) var fullDuration: Double = 0
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var thumbnailTask: Task<Void, Never>?
    private var isWindowFocused = true
    private var resumePlaybackOnFocus = false

    init(source: URL, settings: AppSettings = .shared) {
        self.source = source
        self.settings = settings
        player = AVPlayer(url: source)
    }

    var canExport: Bool { range != nil && !isExporting }
    private var filename: String { source.deletingPathExtension().lastPathComponent + "." + format.fileExtension }
    var maximumFrameRate: Int { min(originalFrameRate, 60) }
    private var savedFrameRate: Int {
        let saved = UserDefaults.standard.integer(forKey: "export-fps-\(format.rawValue)")
        return saved > 0 ? saved : (format == .gif ? 15 : 60)
    }

    func setWidth(_ width: Int) {
        guard sourceSize.width > 0 else { return }
        let ratio = sourceSize.width / sourceSize.height
        outputWidth = min(Int(sourceSize.width), max(max(1, Int(ceil(ratio))), width))
        outputHeight = Int(ratio > 1 ? ceil(Double(outputWidth) / ratio) : floor(Double(outputWidth) / ratio))
        copied = false
    }

    func setHeight(_ height: Int) {
        guard sourceSize.height > 0 else { return }
        let ratio = sourceSize.width / sourceSize.height
        outputHeight = min(Int(sourceSize.height), max(max(1, Int(ceil(1 / ratio))), height))
        outputWidth = Int(ratio > 1 ? floor(Double(outputHeight) * ratio) : ceil(Double(outputHeight) * ratio))
        copied = false
    }

    func setFrameRate(_ value: Int) {
        frameRate = min(maximumFrameRate, max(min(5, maximumFrameRate), value))
        copied = false
    }

    func load(autoPlay: Bool = true) async {
        guard range == nil else { return }
        do {
            guard let asset = player.currentItem?.asset else { throw ExportError.missingVideo }
            fullDuration = try await asset.load(.duration).seconds
            guard let video = try await asset.loadTracks(withMediaType: .video).first else { throw ExportError.missingVideo }
            let naturalSize = try await video.load(.naturalSize)
            let transform = try await video.load(.preferredTransform)
            let oriented = CGRect(origin: .zero, size: naturalSize).applying(transform)
            sourceSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))
            outputWidth = Int(sourceSize.width.rounded())
            outputHeight = Int(sourceSize.height.rounded())
            originalFrameRate = max(1, Int((try await video.load(.nominalFrameRate)).rounded()))
            frameRate = min(maximumFrameRate, savedFrameRate)
            let audio = try await asset.loadTracks(withMediaType: .audio)
            let mix = AVMutableAudioMix()
            mix.inputParameters = audio.map { track in
                let parameters = AVMutableAudioMixInputParameters(track: track)
                parameters.setVolume(1, at: .zero)
                return parameters
            }
            player.currentItem?.audioMix = mix
            range = try ClipRange(start: 0, end: fullDuration)
            updatePlaybackBounds()
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
                let seconds = time.seconds
                Task { @MainActor in self?.currentTime = seconds }
            }
            endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.isPlaying, let range = self.range else { return }
                    self.player.seek(to: range.timeRange.start, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                        Task { @MainActor in if finished, self?.isPlaying == true { self?.player.play() } }
                    }
                }
            }
            if autoPlay {
                if isWindowFocused { togglePlayback() }
                else { resumePlaybackOnFocus = true }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func togglePlayback() {
        guard !isExporting, let range else { return }
        if isPlaying {
            pausePlayback()
        } else {
            isPlaying = true
            if currentTime >= range.end - 1.0 / 600 { seek(to: range.start) }
            player.play()
        }
    }

    func pausePlayback() {
        isPlaying = false
        player.pause()
    }

    func windowFocusChanged(isFocused: Bool) {
        guard isWindowFocused != isFocused else { return }
        isWindowFocused = isFocused
        if isFocused {
            if resumePlaybackOnFocus && !isPlaying { togglePlayback() }
            resumePlaybackOnFocus = false
        } else {
            resumePlaybackOnFocus = isPlaying
            pausePlayback()
        }
    }

    func seek(to time: Double) {
        guard let range else { return }
        let target = min(max(time, range.start), max(range.start, range.end - 1.0 / 600))
        currentTime = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func beginDragging() {
        hideThumbnail()
        isResizingRange = true
        pausePlayback()
    }

    func endDragging() {
        isResizingRange = false
        hideThumbnail()
        if !isPlaying { togglePlayback() }
    }

    func showThumbnail(at fraction: Double) {
        guard let range else { return }
        hoverFraction = min(1, max(0, fraction))
        let time = range.start + hoverFraction * range.duration
        if let hoverTime, abs(time - hoverTime) < 0.05 { return }
        hoverTime = time
        thumbnailTask?.cancel()
        thumbnailTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(40))
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: source))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 264, height: 152)
                let result = try await generator.image(at: CMTime(seconds: min(time, fullDuration - 1.0 / 600), preferredTimescale: 600))
                try Task.checkCancellation()
                thumbnail = NSImage(cgImage: result.image, size: .zero)
            } catch {}
        }
    }

    func hideThumbnail() {
        thumbnailTask?.cancel()
        thumbnailTask = nil
        hoverTime = nil
        thumbnail = nil
    }

    func updateTrim(start: Double? = nil, end: Double? = nil) {
        guard !isExporting, let previous = range else { return }
        let gap = min(1.0 / 60, fullDuration)
        let lower = start.map { min(max(0, $0), previous.end - gap) } ?? previous.start
        let upper = end.map { min(max(lower + gap, $0), fullDuration) } ?? previous.end
        guard let updated = try? ClipRange(start: lower, end: upper) else { return }
        range = updated
        copied = false
        updatePlaybackBounds()
        seek(to: start != nil ? updated.start : updated.end)
        if isResizingRange {
            hoverTime = currentTime
            hoverFraction = (start != nil ? updated.start : updated.end) / fullDuration
        }
    }

    private func updatePlaybackBounds() {
        guard let range else { return }
        player.currentItem?.reversePlaybackEndTime = range.timeRange.start
        player.currentItem?.forwardPlaybackEndTime = range.timeRange.end
    }

    func save() async {
        guard canExport, let window = playerView?.window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = filename
        panel.directoryURL = settings.exportDirectory
        guard await panel.beginSheetModal(for: window) == .OK, let destination = panel.url else { return }
        beginExport(to: destination, copy: false)
    }

    func copy() {
        guard canExport else { return }
        let directory = URL.cachesDirectory.appending(path: "Kapp/Clipboard/\(UUID().uuidString)", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            beginExport(to: directory.appending(path: filename), copy: true)
        } catch { errorMessage = error.localizedDescription }
    }

    private func beginExport(to destination: URL, copy: Bool) {
        guard canExport, let range else { return }
        guard destination.resolvingSymlinksInPath().standardizedFileURL != source.resolvingSymlinksInPath().standardizedFileURL else {
            errorMessage = ExportError.replacesOriginal.localizedDescription
            return
        }
        isExporting = true
        copied = false
        pausePlayback()
        let muted = muted
        let format = format
        let settings = VideoExportSettings(width: outputWidth, height: outputHeight, frameRate: frameRate)
        UserDefaults.standard.set(frameRate, forKey: "export-fps-\(format.rawValue)")
        exportTask = Task {
            // Export beside the destination, then replace it only after successful completion.
            let staging = destination.deletingLastPathComponent().appending(path: ".kapp-\(UUID().uuidString).\(format.fileExtension)")
            defer {
                try? FileManager.default.removeItem(at: staging)
                isExporting = false
                exportTask = nil
            }
            do {
                switch format {
                case .mp4:
                    try await RecordingExporter.exportMP4(source: source, range: range, muted: muted, settings: settings, to: staging)
                case .gif:
                    try await GIFExporter.export(source: source, range: range, settings: settings, to: staging)
                }
                try Task.checkCancellation()
                if FileManager.default.fileExists(atPath: destination.path()) {
                    _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)
                } else {
                    try FileManager.default.moveItem(at: staging, to: destination)
                }
                if copy {
                    try RecordingClipboard.copy(file: destination, format: format)
                    copied = true
                }
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
        }
    }

    func cancelExport() { exportTask?.cancel() }

    func close() {
        hideThumbnail()
        cancelExport()
        pausePlayback()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }
}
