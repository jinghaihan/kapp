import CoreGraphics
import Testing
@testable import Kapp

struct SelectionGeometryTests {
    @Test func convertsGlobalCoordinatesOnASecondaryDisplay() {
        let result = SelectionGeometry.sourceRect(
            for: CGRect(x: -1300, y: 200, width: 401, height: 301),
            on: CGRect(x: -1440, y: 100, width: 1440, height: 900),
            scale: 1
        )
        #expect(result == CGRect(x: 140, y: 499, width: 402, height: 302))
    }

    @Test func preservesRetinaPointsWhileAligningPixelDimensions() {
        let result = SelectionGeometry.sourceRect(
            for: CGRect(x: 20, y: 30, width: 100.25, height: 70.25),
            on: CGRect(x: 0, y: 0, width: 1440, height: 900),
            scale: 2
        )
        #expect(result.width == 101)
        #expect(result.height == 71)
        #expect(result.minY == 799.75)
    }

    @Test func pixelAlignmentDoesNotExtendBeyondDisplayEdges() {
        let result = SelectionGeometry.sourceRect(
            for: CGRect(x: 1339, y: 0, width: 101, height: 101),
            on: CGRect(x: 0, y: 0, width: 1440, height: 900),
            scale: 1
        )
        #expect(result.maxX == 1440)
        #expect(result.maxY == 900)
        #expect(result.size == CGSize(width: 102, height: 102))
    }
}
