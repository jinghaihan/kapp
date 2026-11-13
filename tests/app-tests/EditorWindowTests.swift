import AppKit
import Testing
@testable import Kapp

@MainActor
struct EditorWindowTests {
    @Test func editorSupportsEnteringFullScreen() throws {
        _ = NSApplication.shared
        let editor = EditorWindowController(source: URL.temporaryDirectory.appending(path: "kapp-fullscreen-test.mp4"))
        let window = try #require(editor.window)
        #expect(window.collectionBehavior.contains(.fullScreenPrimary))
        #expect(!window.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    @Test func closedEditorCannotResumePlaybackOrExport() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = EditorModel(source: try await RecordingFixture.make(in: directory))
        await model.load()
        await model.close().value
        await model.load()
        model.togglePlayback()
        #expect(!model.isPlaying)
        #expect(!model.canExport)
        #expect(model.player.currentItem == nil)
    }

    @Test func losingFocusPausesAndReturningRestoresPlayback() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = EditorModel(source: try await RecordingFixture.make(in: directory))
        defer { model.close() }
        await model.load()
        #expect(model.isPlaying)
        model.windowFocusChanged(isFocused: false)
        #expect(!model.isPlaying)
        model.windowFocusChanged(isFocused: true)
        #expect(model.isPlaying)
        model.pausePlayback()
        model.windowFocusChanged(isFocused: false)
        model.windowFocusChanged(isFocused: true)
        #expect(!model.isPlaying, "Returning must not start a preview the user had paused.")
    }

    @Test func loadingInTheBackgroundWaitsForFocusToPlay() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = EditorModel(source: try await RecordingFixture.make(in: directory))
        defer { model.close() }
        model.windowFocusChanged(isFocused: false)
        await model.load()
        #expect(!model.isPlaying)
        model.windowFocusChanged(isFocused: true)
        #expect(model.isPlaying)
    }

    @Test func newRecordingsRequireConfirmationButOpenedFilesDoNot() throws {
        _ = NSApplication.shared
        let source = URL.temporaryDirectory.appending(path: "kapp-close-test.mp4")
        let recording = EditorWindowController(source: source, isNewRecording: true)
        let window = try #require(recording.window)
        var confirmations = 0
        recording.confirmDiscard = { _ in confirmations += 1; return false }
        #expect(!recording.windowShouldClose(window))
        #expect(confirmations == 1)
        #expect(window.isDocumentEdited)
        recording.confirmDiscard = { _ in confirmations += 1; return true }
        #expect(recording.windowShouldClose(window))
        #expect(confirmations == 2)

        let opened = EditorWindowController(source: source)
        opened.confirmDiscard = { _ in Issue.record("Opened files should close without a discard prompt."); return false }
        #expect(opened.windowShouldClose(try #require(opened.window)))
        #expect(!opened.window!.isDocumentEdited)
    }

    @Test func closingReleasesTheOldPreviewBeforeOpeningAnotherRecording() throws {
        _ = NSApplication.shared
        let source = URL.temporaryDirectory.appending(path: "kapp-close-\(UUID().uuidString).mp4")
        try Data("original recording".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let first = EditorWindowController(source: source, isNewRecording: true)
        let oldWindow = try #require(first.window)
        var didClose = false
        first.onClose = {
            #expect(oldWindow.contentView == nil)
            didClose = true
        }
        first.confirmDiscard = { _ in true }
        oldWindow.performClose(nil)
        #expect(didClose)
        #expect(!oldWindow.isVisible)
        #expect(oldWindow.contentView == nil)

        let second = EditorWindowController(source: source, isNewRecording: true)
        #expect(second.window !== oldWindow)
        #expect(oldWindow.contentView == nil)
        #expect(try Data(contentsOf: source) == Data("original recording".utf8))
    }
}
