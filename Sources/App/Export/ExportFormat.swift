import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4"
    case gif = "GIF"

    var id: Self { self }
    var fileExtension: String { self == .mp4 ? "mp4" : "gif" }
    var contentType: UTType { self == .mp4 ? .mpeg4Movie : .gif }
}
