import Testing
import ExzemaCore

@Suite("Location quality")
struct LocationQualityTests {
    @Test(arguments: [-1.0, -0.001, Double.nan, Double.infinity, 5_000.1, 20_000])
    func aFixThatIsInvalidOrTooCoarseIsNotUsed(accuracy: Double) {
        #expect(!LocationQuality.isUsable(horizontalAccuracy: accuracy))
    }

    @Test(arguments: [0.0, 5.0, 65.0, 1_000.0, 3_000.0, 5_000.0])
    func aFixWithinTheLimitIsUsed(accuracy: Double) {
        #expect(LocationQuality.isUsable(horizontalAccuracy: accuracy))
    }

    @Test func theLimitIsUnderHalfOfTheRoundingCell() {
        #expect(LocationQuality.maximumUncertainty < 5_550, "the cell is 0.1 degrees, about 11.1 km, so a fix is off by less than half of it")
    }

    @Test func theNewestUsableFixIsChosenAndInvalidOnesAreSkipped() {
        let good = Coordinate(latitude: 37.7, longitude: -122.4)
        let newer = Coordinate(latitude: 37.8, longitude: -122.5)
        let invalid = LocationFix(coordinate: Coordinate(latitude: 0, longitude: 0), horizontalAccuracy: -1)
        let coarse = LocationFix(coordinate: Coordinate(latitude: 1, longitude: 1), horizontalAccuracy: 25_000)

        #expect(LocationFix.bestUsable([LocationFix(coordinate: good, horizontalAccuracy: 50), invalid, coarse]) == good)
        #expect(LocationFix.bestUsable([LocationFix(coordinate: good, horizontalAccuracy: 50), LocationFix(coordinate: newer, horizontalAccuracy: 900)]) == newer)
        #expect(LocationFix.bestUsable([invalid, coarse]) == nil)
        #expect(LocationFix.bestUsable([]) == nil)
    }
}
