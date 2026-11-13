import Foundation

struct VideoExportSettings: Sendable {
    let width: Int
    let height: Int
    let frameRate: Int

    func validate() throws {
        guard width > 0, height > 0, (1...60).contains(frameRate) else { throw ExportError.invalidSettings }
    }

    var size: CGSize { CGSize(width: width, height: height) }
}
