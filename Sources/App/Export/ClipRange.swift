import CoreMedia
import Foundation

struct ClipRange: Equatable, Sendable {
    let start: Double
    let end: Double

    init(start: Double, end: Double) throws {
        guard start.isFinite, end.isFinite, start >= 0, end > start else {
            throw ExportError.invalidRange
        }
        self.start = start
        self.end = end
    }

    var duration: Double { end - start }

    var timeRange: CMTimeRange {
        CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                    end: CMTime(seconds: end, preferredTimescale: 600))
    }

    func validate(duration: Double) throws {
        guard duration.isFinite, end <= duration + 1.0 / 600 else {
            throw ExportError.invalidRange
        }
    }
}
