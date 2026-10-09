import Foundation
import Testing
import ExzemaCore

@Suite("Capture metadata")
struct CaptureMetadataTests {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func instant(_ iso: String) throws -> Date {
        try #require(try? Date(iso, strategy: Date.ISO8601FormatStyle()))
    }

    private func metadata(_ time: String?, offset: String? = nil) -> CaptureMetadata {
        CaptureMetadata(lensModel: nil, dateTimeOriginal: time, offsetTimeOriginal: offset)
    }

    @Test func shutterTimeUsesTheRecordedOffset() throws {
        let shutter = metadata("2026:10:08 20:37:11", offset: "-07:00").shutterTime(fallbackZone: tokyo)

        #expect(shutter == (try instant("2026-10-09T03:37:11Z")), "the offset wins over the fallback zone")
    }

    @Test func shutterTimeFallsBackToTheGivenZoneWithoutAnOffset() throws {
        let shutter = metadata("2026:10:08 20:37:11").shutterTime(fallbackZone: losAngeles)

        #expect(shutter == (try instant("2026-10-09T03:37:11Z")))
    }

    @Test func malformedOffsetFallsBackToTheGivenZone() throws {
        let shutter = metadata("2026:10:08 20:37:11", offset: "later").shutterTime(fallbackZone: losAngeles)

        #expect(shutter == (try instant("2026-10-09T03:37:11Z")))
    }

    @Test func photoShotJustBeforeMidnightKeepsItsDayWhateverTheTimeItIsAccepted() throws {
        let shutter = try #require(metadata("2026:10:08 23:59:55", offset: "-07:00").shutterTime(fallbackZone: losAngeles))

        #expect(Day(loggedAt: shutter, in: losAngeles).date == LocalDate(year: 2026, month: 10, day: 8))
    }

    @Test func photoShotJustAfterMidnightIsOnTheNextDay() throws {
        let shutter = try #require(metadata("2026:10:09 00:00:05", offset: "-07:00").shutterTime(fallbackZone: losAngeles))

        #expect(Day(loggedAt: shutter, in: losAngeles).date == LocalDate(year: 2026, month: 10, day: 9))
    }

    @Test(arguments: [nil, "", "not a time", "2026-10-08 20:37:11", "2026:13:08 20:37:11", "2026:10:32 20:37:11", "2026:10:08 25:00:00"])
    func missingOrMalformedTimeGivesNoShutterTime(time: String?) {
        #expect(metadata(time).shutterTime(fallbackZone: losAngeles) == nil)
    }
}
