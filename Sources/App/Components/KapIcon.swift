import AppKit
import SwiftUI

struct KapIcon: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
        Image(nsImage: image).resizable().renderingMode(.template).frame(width: size, height: size)
    }

    private var image: NSImage {
        let installed = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appending(path: "Kapp_Kapp.bundle")) }
        let bundle = installed ?? .module
        guard let url = bundle.url(forResource: "kap-\(name)", withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { return NSImage(size: NSSize(width: 24, height: 24)) }
        image.isTemplate = true
        return image
    }
}
