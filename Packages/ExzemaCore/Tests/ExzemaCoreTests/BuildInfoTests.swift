import Testing
import ExzemaCore

@Suite("Build info")
struct BuildInfoTests {
    @Test func buildTimestampIsShownAsIs() {
        #expect(BuildInfo(stamp: "20261007164512").label == "Build 20261007164512")
    }

    @Test func stampIsAvailableAsANumberForLogging() {
        #expect(BuildInfo(stamp: "20261007164512").number == 20_261_007_164_512)
        #expect(BuildInfo(stamp: nil).number == nil)
    }

    @Test func missingVersionIsShownAsUnknown() {
        #expect(BuildInfo(stamp: nil).label == "Build unknown")
    }

    @Test(arguments: ["1", "", "2026-10-07", "2026100716451", "202610071645123", "2026100716451x"])
    func stampThatIsNotAFourteenDigitTimestampIsShownAsUnknown(version: String) {
        #expect(BuildInfo(stamp: version).label == "Build unknown", "an unstamped build must not look stamped")
    }
}
