import AppKit
@preconcurrency import AVFoundation
import AVKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class EditorModel {
    let source: URL
    let player: AVPlayer
    private(set) var range: ClipRange?
    private(set) var isExporting = false
    private(set) var copied = false
    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false
    var format: ExportFormat = .mp4 {
        didSet {
            player.isMuted = muted || format == .gif
            copied = false
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
    @ObservationIgnored private var resumeAfterDragging = false

    init(source: URL) {
        self.source = source
        player = AVPlayer(url: source)
    }

    var canExport: Bool { range != nil && !isExporting }
    private var filename: String { source.deletingPathExtension().lastPathComponent + "." + format.fileExtension }

    func load(autoPlay: Bool = true) async {
        guard range == nil else { return }
        do {
            guard let asset = player.currentItem?.asset else { throw ExportError.missingVideo }
            fullDuration = try await asset.load(.duration).seconds
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
            if autoPlay { togglePlayback() }
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

    func seek(to time: Double) {
        guard let range else { return }
        let target = min(max(time, range.start), max(range.start, range.end - 1.0 / 600))
        currentTime = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func beginDragging() {
        resumeAfterDragging = isPlaying
        pausePlayback()
    }

    func endDragging() {
        if resumeAfterDragging { togglePlayback() }
        resumeAfterDragging = false
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
        panel.directoryURL = .downloadsDirectory
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
                    try await RecordingExporter.exportMP4(source: source, range: range, muted: muted, to: staging)
                case .gif:
                    try await GIFExporter.export(source: source, range: range, to: staging)
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
        cancelExport()
        pausePlayback()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }
}
