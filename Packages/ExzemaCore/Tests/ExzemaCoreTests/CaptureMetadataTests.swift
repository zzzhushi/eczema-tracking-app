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

    @Test func shutterMomentUsesTheRecordedOffset() throws {
        let moment = try #require(metadata("2026:10:08 20:37:11", offset: "-07:00").shutterMoment(fallbackZone: tokyo))

        #expect(moment.instant == (try instant("2026-10-09T03:37:11Z")), "the offset wins over the fallback zone")
    }

    @Test func shutterMomentCarriesTheZoneItWasReadIn() throws {
        let moment = try #require(metadata("2026:10:08 20:37:11", offset: "-07:00").shutterMoment(fallbackZone: tokyo))

        #expect(moment.timeZone.secondsFromGMT(for: moment.instant) == -7 * 3600, "not the fallback zone")
        #expect(moment.timeZone != tokyo)
    }

    @Test func shutterMomentKeepsTheFallbackZoneWhenItAgreesWithTheOffset() throws {
        let moment = try #require(metadata("2026:10:08 20:37:11", offset: "-07:00").shutterMoment(fallbackZone: losAngeles))

        #expect(moment.timeZone == losAngeles, "a named zone says more than a bare offset")
    }

    @Test func shutterMomentFallsBackToTheGivenZoneWithoutAnOffset() throws {
        let moment = try #require(metadata("2026:10:08 20:37:11").shutterMoment(fallbackZone: losAngeles))

        #expect(moment.instant == (try instant("2026-10-09T03:37:11Z")))
        #expect(moment.timeZone == losAngeles)
    }

    @Test(arguments: ["later", "-oops:00", "+oops:07:00", "+07:00:00", "+15:00", "+07:60", "07:00", ""])
    func malformedOffsetFallsBackToTheGivenZone(offset: String) throws {
        let moment = try #require(metadata("2026:10:08 20:37:11", offset: offset).shutterMoment(fallbackZone: losAngeles))

        #expect(moment.instant == (try instant("2026-10-09T03:37:11Z")))
        #expect(moment.timeZone == losAngeles)
    }

    @Test func photoShotJustBeforeMidnightKeepsItsDayWhateverTheTimeItIsAccepted() throws {
        let moment = try #require(metadata("2026:10:08 23:59:55", offset: "-07:00").shutterMoment(fallbackZone: losAngeles))

        #expect(Day(loggedAt: moment.instant, in: moment.timeZone).date == LocalDate(year: 2026, month: 10, day: 8))
    }

    @Test func photoShotJustAfterMidnightIsOnTheNextDay() throws {
        let moment = try #require(metadata("2026:10:09 00:00:05", offset: "-07:00").shutterMoment(fallbackZone: losAngeles))

        #expect(Day(loggedAt: moment.instant, in: moment.timeZone).date == LocalDate(year: 2026, month: 10, day: 9))
    }

    @Test func localDayFollowsTheRecordedZoneNotTheFallbackZone() throws {
        let moment = try #require(metadata("2026:10:08 23:30:00", offset: "-07:00").shutterMoment(fallbackZone: tokyo))

        #expect(Day(loggedAt: moment.instant, in: moment.timeZone).date == LocalDate(year: 2026, month: 10, day: 8))
        #expect(Day(loggedAt: moment.instant, in: tokyo).date == LocalDate(year: 2026, month: 10, day: 9), "the fallback zone would give the next day")
    }

    @Test(arguments: [
        nil, "", "not a time", "2026-10-08 20:37:11",
        "2026:13:08 20:37:11", "2026:10:32 20:37:11", "2026:10:08 25:00:00",
        "2026:oops:08 20:37:11", "2026:oops:10:08 20:37:11", "2026:10:08 20:37:11:oops", "2026:10:08 20:oops:11",
        "2026:10:08  20:37:11", "2026:10:08", "2026:+1:08 20:37:11", "2026::08 20:37:11",
    ])
    func missingOrMalformedTimeGivesNoShutterMoment(time: String?) {
        #expect(metadata(time).shutterMoment(fallbackZone: losAngeles) == nil)
    }
}
