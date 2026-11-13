import Foundation

enum TrimGeometry {
    static let handleWidth: Double = 5

    static func position(for time: Double, duration: Double, width: Double) -> Double {
        guard duration > 0, width > handleWidth else { return handleWidth / 2 }
        return handleWidth / 2 + min(1, max(0, time / duration)) * (width - handleWidth)
    }

    static func time(at position: Double, duration: Double, width: Double) -> Double {
        guard duration > 0, width > handleWidth else { return 0 }
        return min(1, max(0, (position - handleWidth / 2) / (width - handleWidth))) * duration
    }
}
