import Testing
@testable import Kapp

struct ClipRangeTests {
    @Test func rejectsEmptyReversedAndNonFiniteRanges() {
        for (start, end) in [(0.0, 0.0), (2.0, 1.0), (-1.0, 1.0), (0.0, Double.infinity), (Double.nan, 1.0)] {
            #expect(throws: ExportError.self) { try ClipRange(start: start, end: end) }
        }
    }

    @Test func preservesBothTrimEndpoints() throws {
        let range = try ClipRange(start: 2.5, end: 8.25)
        #expect(range.timeRange.start.seconds == 2.5)
        #expect(range.timeRange.end.seconds == 8.25)
        #expect(range.duration == 5.75)
        try range.validate(duration: 10)
        #expect(throws: ExportError.self) { try range.validate(duration: 8) }
    }
}
