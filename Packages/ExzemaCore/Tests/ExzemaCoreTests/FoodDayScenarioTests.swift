import Foundation
import Testing
import ExzemaCore

/// A few journeys across the host, the drafts, the food model, and the store. The policy for each event is
/// owned by `DayHostModelTests` and the draft state transitions by `FoodDraftsTests`.
@MainActor
@Suite("Food day journeys")
struct FoodDayScenarioTests {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let honolulu = TimeZone(identifier: "Pacific/Honolulu")!
    private let lateEvening = Date(timeIntervalSince1970: 1_791_442_680) // 2026-10-07 23:58 in Los Angeles
    private let oct7 = LocalDate(year: 2026, month: 10, day: 7)
    private let oct8 = LocalDate(year: 2026, month: 10, day: 8)

    private final class Clock: @unchecked Sendable {
        var now: Date
        var timeZone: TimeZone
        init(_ now: Date, _ timeZone: TimeZone) { self.now = now; self.timeZone = timeZone }
    }

    /// The app's day screen: a session over a temporary store. The food model is built for the day on screen
    /// each time it is asked for, as the screen does by giving the food section the day as its identity.
    @MainActor
    private struct App {
        let clock: Clock
        let session: DaySession
        let store: DayStore
        let matcher: FoodMatcher

        init(clock: Clock) throws {
            self.clock = clock
            session = DaySession(clock: { clock.now }, timeZone: { clock.timeZone })
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FoodDayScenarioTests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            store = try DayStore(at: directory.appendingPathComponent("store.sqlite"))
            matcher = try FoodMatching.load(dataDirectory: shippedDataDirectory).matcher
        }

        var host: DayHostModel { session.host }
        var model: FoodLogModel { session.makeFoodLogModel(for: host.day, store: store, matcher: matcher) }

        func advance(_ seconds: TimeInterval) { clock.now = clock.now.addingTimeInterval(seconds); session.handle(.clockChanged) }
        func changeTimeZone(to zone: TimeZone) { clock.timeZone = zone; session.handle(.clockChanged) }
        func lines(on date: LocalDate) throws -> [String] { try store.foodLines(on: date).map(\.text) }
    }

    private func makeApp(timeZone: TimeZone? = nil) throws -> App {
        try App(clock: Clock(lateEvening, timeZone ?? losAngeles))
    }

    @Test func dinnerTypedBeforeMidnightIsSavedOnTheDayItWasTypedFor() throws {
        let app = try makeApp()
        app.model.updateDraft("rice and tofu")

        app.advance(180)
        app.model.save()

        #expect(app.host.day.date == oct7)
        #expect(try app.lines(on: oct7) == ["rice and tofu"])
        #expect(try app.lines(on: oct8).isEmpty)
    }

    @Test func returningTheNextMorningWithUnsavedTextKeepsThatDayAndItsText() throws {
        let app = try makeApp()
        app.model.updateDraft("rice")
        app.session.handle(.enteredBackground)

        app.clock.now = app.clock.now.addingTimeInterval(10 * 3600)
        app.session.handle(.becameActive)

        #expect(app.host.day.date == oct7 && !app.host.isShowingToday)
        #expect(app.model.draft == "rice")
    }

    @Test func aDraftOnADateThatBecameFutureAfterATimeZoneChangeIsKeptAndSavesOnThatDate() throws {
        let app = try makeApp(timeZone: tokyo) // 2026-10-08 15:58
        app.model.updateDraft("rice and tofu")

        app.changeTimeZone(to: honolulu) // 2026-10-07 20:58
        #expect(app.host.day.date == oct8 && app.model.draft == "rice and tofu")
        app.model.save()

        #expect(try app.lines(on: oct8) == ["rice and tofu"])
    }

    @Test func anEditAndAHeldNewEntrySurviveMidnight() throws {
        let app = try makeApp()
        app.model.updateDraft("rice")
        app.model.save()
        app.model.updateDraft("a late snack of oatmeal")
        app.model.beginEditing(try #require(app.model.lines.first))
        app.model.updateDraft("rice and tofu")

        app.advance(180)
        app.model.save()

        #expect(try app.lines(on: oct7) == ["rice and tofu"])
        #expect(app.model.draft == "a late snack of oatmeal")
    }
}
