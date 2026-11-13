import AppKit
import Testing
@testable import Kapp

@MainActor
struct RecordingFilesTests {
    @Test func closingARecordingDeletesOnlyItsOriginal() async throws {
        _ = NSApplication.shared
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = RecordingFiles(directory: directory)
        let source = files.makeURL()
        let otherRecording = files.makeURL()
        let exported = directory.appending(path: "exported.mp4")
        try Data("original".utf8).write(to: source)
        try Data("another recording".utf8).write(to: otherRecording)
        try Data("exported".utf8).write(to: exported)
        let editor = EditorWindowController(source: source, isNewRecording: true, recordingFiles: files)
        editor.confirmDiscard = { _ in false }
        editor.window?.performClose(nil)
        #expect(FileManager.default.fileExists(atPath: source.path))
        editor.confirmDiscard = { _ in true }
        editor.window?.performClose(nil)
        // Wait for the window's scheduled cleanup, without invoking the quit fallback.
        await files.waitForClosedEditors()
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: otherRecording.path))
        #expect(try Data(contentsOf: exported) == Data("exported".utf8))
    }

    @Test func closingAnOpenedVideoKeepsItsFile() async throws {
        _ = NSApplication.shared
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = RecordingFiles(directory: directory)
        let source = directory.appending(path: "opened.mp4")
        try Data("external video".utf8).write(to: source)
        let editor = EditorWindowController(source: source, recordingFiles: files)
        editor.window?.performClose(nil)
        try await files.cleanUpAll()
        #expect(try Data(contentsOf: source) == Data("external video".utf8))
    }

    @Test func quitFallbackCleansTrackedOriginalsWithoutSweepingTheDirectory() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = RecordingFiles(directory: directory)
        let source = files.makeURL()
        let other = directory.appending(path: "existing-video.mp4")
        try Data("original".utf8).write(to: source)
        try Data("keep".utf8).write(to: other)
        _ = files.makeURL() // A failed recording may never have created its output file.
        try await files.cleanUpAll()
        try await files.cleanUpAll()
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: other) == Data("keep".utf8))
    }

    @Test func closeAndQuitWaitForPendingExportWorkBeforeDeletingTheSource() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = RecordingFiles(directory: directory)
        let source = files.makeURL()
        try Data("original".utf8).write(to: source)
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let pendingExport = Task { for await _ in stream {} }
        let closed = files.finishEditing(source, after: pendingExport)
        let quit = Task { try await files.cleanUpAll() }
        await Task.yield()
        #expect(FileManager.default.fileExists(atPath: source.path))
        continuation.finish()
        await closed.value
        try await quit.value
        #expect(!FileManager.default.fileExists(atPath: source.path))
    }
}
