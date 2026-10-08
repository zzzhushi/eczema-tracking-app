import Foundation
import Testing
import ExzemaCore

/// The day-boundary scenarios, driven through the same calls the app's notifications and lifecycle make.
@MainActor
@Suite("Food day scenarios")
struct FoodDayScenarioTests {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let lateEvening = Date(timeIntervalSince1970: 1_791_442_680) // 2026-10-07 23:58 in Los Angeles
    private let oct6 = LocalDate(year: 2026, month: 10, day: 6)
    private let oct7 = LocalDate(year: 2026, month: 10, day: 7)
    private let oct8 = LocalDate(year: 2026, month: 10, day: 8)

    private final class Clock: @unchecked Sendable {
        var now: Date
        var timeZone: TimeZone
        init(_ now: Date, _ timeZone: TimeZone) { self.now = now; self.timeZone = timeZone }
    }

    /// Wires the host, drafts, and food model the way the screens do.
    @MainActor
    private struct App {
        let clock: Clock
        let session: DaySession
        let store: DayStore
        let model: FoodLogModel
        var host: DayHostModel { session.host }

        init(clock: Clock, directory: URL) throws {
            self.clock = clock
            session = DaySession(clock: { clock.now }, timeZone: { clock.timeZone })
            store = try DayStore(at: directory.appendingPathComponent("store.sqlite"))
            let matching = try FoodMatching.load(dataDirectory: shippedDataDirectory)
            model = session.makeFoodLogModel(for: session.host.day, store: store, matcher: matching.matcher)
        }

        /// What the food section does when the day on screen changes.
        func sync() { model.show(host.day) }
        func advance(_ seconds: TimeInterval) { clock.now = clock.now.addingTimeInterval(seconds); session.handle(.clockChanged); sync() }
        func tapBack() { host.goBack(); sync() }
        func tapForward() { host.goForward(); sync() }
        func tapToday() { host.goToToday(); sync() }
        func leave() { session.handle(.enteredBackground) }
        func returnAfter(_ seconds: TimeInterval) {
            clock.now = clock.now.addingTimeInterval(seconds)
            session.handle(.becameActive)
            sync()
        }
        func changeTimeZone(to zone: TimeZone) { clock.timeZone = zone; session.handle(.clockChanged); sync() }
        func lines(on date: LocalDate) throws -> [String] { try store.foodLines(on: date).map(\.text) }
    }

    private func makeApp(timeZone: TimeZone? = nil) throws -> App {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FoodDayScenarioTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try App(clock: Clock(lateEvening, timeZone ?? losAngeles), directory: directory)
    }

    @Test func dinnerTypedAtMidnightIsSavedOnTheDayItWasTypedFor() throws {
        let app = try makeApp()
        app.model.updateDraft("rice and tofu")

        app.advance(180)
        #expect(app.model.day.date == oct7 && app.host.daysBack == 1)
        app.model.save()

        #expect(try app.lines(on: oct7) == ["rice and tofu"])
        #expect(try app.lines(on: oct8).isEmpty)
    }

    @Test func anEditOpenAtMidnightUpdatesTheOriginalLine() throws {
        let app = try makeApp()
        app.model.updateDraft("rice")
        app.model.save()
        app.model.beginEditing(try #require(app.model.lines.first))
        app.model.updateDraft("rice and tofu")

        app.advance(180)
        app.model.save()

        #expect(try app.lines(on: oct7) == ["rice and tofu"])
        #expect(try app.store.foodLines(on: oct7).count == 1)
    }

    @Test func backfillingAPastDayContinuesAcrossMidnight() throws {
        let app = try makeApp()
        app.tapBack()
        app.model.updateDraft("oatmeal")

        app.advance(180)
        app.model.save()

        #expect(app.model.day.date == oct6 && app.host.daysBack == 2)
        #expect(try app.lines(on: oct6) == ["oatmeal"])
    }

    @Test func openingTheAppNextMorningWithNothingUnsavedShowsToday() throws {
        let app = try makeApp()
        app.leave()

        app.returnAfter(10 * 3600)

        #expect(app.model.day.date == oct8 && app.host.isShowingToday)
    }

    @Test func openingTheAppNextMorningWithUnsavedTextKeepsThatDayAndText() throws {
        let app = try makeApp()
        app.model.updateDraft("rice")
        app.leave()

        app.returnAfter(10 * 3600)

        #expect(app.model.day.date == oct7 && !app.host.isShowingToday)
        #expect(app.model.draft == "rice")
        app.tapToday()
        #expect(app.model.day.date == oct8 && app.model.draft.isEmpty)
        app.model.updateDraft("oatmeal")
        app.model.save()
        app.tapBack()
        #expect(app.model.draft == "rice", "the text typed for Oct 7 must still be there")
    }

    @Test func textTypedForOneDayStaysWithItWhenSteppingToAnother() throws {
        let app = try makeApp()
        app.model.updateDraft("rice")

        app.tapBack()
        #expect(app.model.draft.isEmpty)
        app.tapForward()

        #expect(app.model.draft == "rice")
    }

    @Test func aTimeZoneChangeDoesNotMoveTheScreenOrTheTypedText() throws {
        let app = try makeApp()
        app.model.updateDraft("rice")

        app.changeTimeZone(to: tokyo)

        #expect(app.model.day.date == oct7 && app.model.day.timeZoneIdentifier == "Asia/Tokyo")
        #expect(app.model.draft == "rice")
        #expect(app.host.today.date == oct8)
    }

    @Test func aDraftOnADateThatBecomesFutureAfterATimeZoneChangeIsNotStranded() throws {
        let app = try makeApp(timeZone: tokyo) // 2026-10-08 15:58
        app.model.updateDraft("rice and tofu")

        app.changeTimeZone(to: TimeZone(identifier: "Pacific/Honolulu")!) // 2026-10-07 20:58

        #expect(app.model.day.date == oct8 && app.model.draft == "rice and tofu")
        app.model.save()
        #expect(try app.lines(on: oct8) == ["rice and tofu"])
    }

    @Test func aDraftOnADateThatBecameFutureIsReachableByStepping() throws {
        let app = try makeApp(timeZone: tokyo)
        app.model.updateDraft("rice and tofu")
        app.changeTimeZone(to: TimeZone(identifier: "Pacific/Honolulu")!)
        app.tapBack()
        #expect(app.model.day.date == oct7 && app.model.draft.isEmpty)

        app.tapForward()

        #expect(app.model.day.date == oct8 && app.model.draft == "rice and tofu")
    }

    @Test func aNewEntryTypedBeforeAnEditSurvivesTheEditAndMidnight() throws {
        let app = try makeApp()
        app.model.updateDraft("rice")
        app.model.save()
        app.model.updateDraft("a late snack of oatmeal")
        app.model.beginEditing(try #require(app.model.lines.first))
        app.model.updateDraft("rice and tofu")

        app.advance(180)
        app.model.save()

        #expect(app.model.day.date == oct7 && app.model.draft == "a late snack of oatmeal")
        #expect(try app.lines(on: oct7) == ["rice and tofu"])
    }
}
