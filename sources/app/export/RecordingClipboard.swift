import AppKit
import UniformTypeIdentifiers

@MainActor
enum RecordingClipboard {
    static func item(for file: URL, format: ExportFormat) throws -> NSPasteboardItem {
        let item = NSPasteboardItem()
        item.setString(file.absoluteString, forType: .fileURL)
        if format == .gif {
            item.setData(try Data(contentsOf: file), forType: NSPasteboard.PasteboardType(UTType.gif.identifier))
        }
        return item
    }

    static func copy(file: URL, format: ExportFormat) throws {
        let item = try item(for: file, format: format)
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.writeObjects([item]) else { throw ExportError.clipboardFailed }
    }
}
