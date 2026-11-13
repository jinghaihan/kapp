import AppKit
import KappRecording
import Observation
import ScreenCaptureKit

@MainActor
@Observable
final class RecorderModel {
    let session = RecordingSession()
    let settings: AppSettings
    var configuration: RecordingConfiguration { settings.recordingConfiguration }
    private(set) var selection: CaptureSelection?
    private(set) var isSelecting = false
    private(set) var savedFile: URL?
    var onFinished: ((URL) -> Void)?
    var onError: ((Error) -> Void)?
    var makeMenu: (() -> NSMenu)?

    private let areaSelector = AreaSelectionOverlay()
    private let border = SelectionBorderFrame()

    init(settings: AppSettings = .shared) {
        self.settings = settings
        session.onFinished = { [weak self] url in
            self?.savedFile = url
            self?.border.dismiss()
            self?.onFinished?(url)
        }
        session.onError = { [weak self] error in self?.onError?(error) }
    }

    var canSelect: Bool { session.state == .idle && !isSelecting }

    func selectArea(showWindowMenu: Bool = false) async {
        guard canSelect else { return }
        isSelecting = true
        border.dismiss()
        defer {
            isSelecting = false
            restoreSelectionBorder()
        }

        guard let area = await areaSelector.present(model: self, showWindowMenu: showWindowMenu) else { return }
        do {
            selection = try await CaptureSelection(area: area)
        } catch {
            onError?(error)
            return
        }
        isSelecting = false
        await start()
    }

    func selectContent() async {
        await selectArea(showWindowMenu: true)
    }

    func start() async {
        guard canSelect, let selection else { return }
        settings.refreshAudioDevices()
        let directory = URL.moviesDirectory.appending(path: "Kapp", directoryHint: .isDirectory)
        let name = "Kapp-\(Date.now.formatted(.iso8601).replacing(":", with: "-"))-\(UUID().uuidString.prefix(8)).mp4"
        do {
            try await session.start(
                filter: selection.filter,
                sourceRect: selection.sourceRect,
                configuration: configuration,
                outputURL: directory.appending(path: name)
            )
        } catch {
            onError?(error)
        }
    }

    func stop() async {
        guard session.state.isRecording else { return }
        do { try await session.stop() } catch { onError?(error) }
    }

    func cancelSelection() {
        areaSelector.cancel()
    }

    private func restoreSelectionBorder() {
        if session.state.isRecording, let rect = selection?.screenRect { border.show(screenRect: rect) }
    }
}
