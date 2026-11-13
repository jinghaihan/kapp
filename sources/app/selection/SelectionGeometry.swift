// Adapted from BetterCapture's RecorderViewModel. MIT; see LICENSE.
import CoreGraphics
import Foundation

enum SelectionGeometry {
    /// Convert global AppKit points to display-local, top-left points, with even pixel dimensions.
    static func sourceRect(for selection: CGRect, on screen: CGRect, scale: CGFloat) -> CGRect {
        let width = min(ceil(selection.width * scale / 2) * 2, floor(screen.width * scale / 2) * 2) / scale
        let height = min(ceil(selection.height * scale / 2) * 2, floor(screen.height * scale / 2) * 2) / scale
        return CGRect(
            x: min(max(0, selection.minX - screen.minX), screen.width - width),
            y: min(max(0, screen.maxY - selection.maxY), screen.height - height),
            width: width,
            height: height
        )
    }
}
