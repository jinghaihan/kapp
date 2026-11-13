import Foundation

@MainActor
final class RecordingFiles {
    static let shared = RecordingFiles()

    private let directory: URL
    private var sources = Set<URL>()
    private var cleanupTasks: [UUID: Task<Void, Never>] = [:]
    var onError: ((Error) -> Void)?

    init(directory: URL = URL.moviesDirectory.appending(path: "Kapp", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func makeURL() -> URL {
        let name = "Kapp-\(Date.now.formatted(.iso8601).replacing(":", with: "-"))-\(UUID().uuidString.prefix(8)).mp4"
        let source = directory.appending(path: name)
        sources.insert(source)
        return source
    }

    @discardableResult
    func finishEditing(_ source: URL?, after pendingWork: Task<Void, Never>) -> Task<Void, Never> {
        let id = UUID()
        let task = Task {
            defer { cleanupTasks[id] = nil }
            await pendingWork.value
            if let source {
                do { try remove(source) }
                catch { onError?(error) }
            }
        }
        cleanupTasks[id] = task
        return task
    }

    func cleanUpAll() async throws {
        // Closed editors may still be cancelling an export that reads the original.
        await waitForClosedEditors()
        var firstError: Error?
        for source in Array(sources) {
            do { try remove(source) }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
    }

    func waitForClosedEditors() async {
        for task in Array(cleanupTasks.values) { await task.value }
    }

    private func remove(_ source: URL) throws {
        guard sources.contains(source) else { return }
        if FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.removeItem(at: source)
        }
        sources.remove(source)
    }
}
