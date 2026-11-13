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
    private(set) var isTrimming = false
    private(set) var isExporting = false
    private(set) var copied = false
    var canTrim = false
    var muted = false {
        didSet { player.isMuted = muted }
    }
    var errorMessage: String?

    @ObservationIgnored weak var playerView: AVPlayerView?
    @ObservationIgnored private var exportTask: Task<Void, Never>?
    @ObservationIgnored private var fullDuration: Double = 0

    init(source: URL) {
        self.source = source
        player = AVPlayer(url: source)
    }

    var canExport: Bool { range != nil && !isExporting && !isTrimming }

    func load() async {
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
        } catch { errorMessage = error.localizedDescription }
    }

    func trim() async {
        guard let playerView, playerView.canBeginTrimming, !isExporting, !isTrimming else { return }
        player.pause()
        isTrimming = true
        defer { isTrimming = false }
        let result = await playerView.beginTrimming()
        if result == .okButton, let item = player.currentItem {
            do {
                let start = item.reversePlaybackEndTime.isNumeric ? item.reversePlaybackEndTime.seconds : 0
                let end = item.forwardPlaybackEndTime.isNumeric ? item.forwardPlaybackEndTime.seconds : fullDuration
                range = try ClipRange(start: max(0, start), end: min(end, fullDuration))
                copied = false
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func save() async {
        guard canExport, let window = playerView?.window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = source.lastPathComponent
        panel.directoryURL = .downloadsDirectory
        guard await panel.beginSheetModal(for: window) == .OK, let destination = panel.url else { return }
        beginExport(to: destination, copy: false)
    }

    func copy() {
        guard canExport else { return }
        let directory = URL.cachesDirectory.appending(path: "Kapp/Clipboard/\(UUID().uuidString)", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            beginExport(to: directory.appending(path: source.lastPathComponent), copy: true)
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
        player.pause()
        let muted = muted
        exportTask = Task {
            // Export beside the destination, then replace it only after successful completion.
            let staging = destination.deletingLastPathComponent().appending(path: ".kapp-\(UUID().uuidString).mp4")
            defer {
                try? FileManager.default.removeItem(at: staging)
                isExporting = false
                exportTask = nil
            }
            do {
                try await RecordingExporter.exportMP4(source: source, range: range, muted: muted, to: staging)
                try Task.checkCancellation()
                if FileManager.default.fileExists(atPath: destination.path()) {
                    _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)
                } else {
                    try FileManager.default.moveItem(at: staging, to: destination)
                }
                if copy {
                    NSPasteboard.general.clearContents()
                    guard NSPasteboard.general.writeObjects([destination as NSURL]) else {
                        throw ExportError.clipboardFailed
                    }
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
        player.pause()
    }
}
