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
        let host: DayHostModel
        let drafts = FoodDrafts()
        let store: DayStore
        let model: FoodLogModel

        init(clock: Clock, directory: URL) throws {
            self.clock = clock
            host = DayHostModel(clock: { clock.now }, timeZone: { clock.timeZone })
            store = try DayStore(at: directory.appendingPathComponent("store.sqlite"))
            let matching = try FoodMatching.load(dataDirectory: shippedDataDirectory)
            model = FoodLogModel(day: host.day, store: store, matcher: matching.matcher, drafts: drafts)
        }

        func sync() { model.show(host.day) }
        func advance(_ seconds: TimeInterval) { clock.now = clock.now.addingTimeInterval(seconds); host.refresh(); sync() }
        func tapBack() { host.goBack(); sync() }
        func tapForward() { host.goForward(); sync() }
        func tapToday() { host.goToToday(); sync() }
        func leave() { host.wentToBackground() }
        func returnAfter(_ seconds: TimeInterval) {
            clock.now = clock.now.addingTimeInterval(seconds)
            host.becameActive(hasUnsavedWork: drafts.hasUnsavedWork(on: host.day.date))
            sync()
        }
        func lines(on date: LocalDate) throws -> [String] { try store.foodLines(on: date).map(\.text) }
    }

    private func makeApp(timeZone: TimeZone? = nil) throws -> App {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FoodDayScenarioTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try App(clock: Clock(lateEvening, timeZone ?? losAngeles), directory: directory)
    }

    @Test func a_dinnerTypedAtMidnightIsSavedOnTheDayItWasTypedFor() throws {
        let app = try makeApp()
        app.model.updateDraft("rice and tofu")

        app.advance(180)
        #expect(app.model.day.date == oct7 && app.host.daysBack == 1)
        app.model.save()

        #expect(try app.lines(on: oct7) == ["rice and tofu"])
        #expect(try app.lines(on: oct8).isEmpty)
    }

    @Test func b_anEditOpenAtMidnightUpdatesTheOriginalLine() throws {
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

    @Test func c_backfillingAPastDayContinuesAcrossMidnight() throws {
        let app = try makeApp()
        app.tapBack()
        app.model.updateDraft("oatmeal")

        app.advance(180)
        app.model.save()

        #expect(app.model.day.date == oct6 && app.host.daysBack == 2)
        #expect(try app.lines(on: oct6) == ["oatmeal"])
    }

    @Test func d_openingTheAppNextMorningWithNothingUnsavedShowsToday() throws {
        let app = try makeApp()
        app.leave()

        app.returnAfter(10 * 3600)

        #expect(app.model.day.date == oct8 && app.host.isShowingToday)
    }

    @Test func e_openingTheAppNextMorningWithUnsavedTextKeepsThatDayAndText() throws {
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

    @Test func f_textTypedForOneDayStaysWithItWhenSteppingToAnother() throws {
        let app = try makeApp()
        app.model.updateDraft("rice")

        app.tapBack()
        #expect(app.model.draft.isEmpty)
        app.tapForward()

        #expect(app.model.draft == "rice")
    }

    @Test func g_aTimeZoneChangeDoesNotMoveTheScreenOrTheTypedText() throws {
        let app = try makeApp()
        app.model.updateDraft("rice")

        app.clock.timeZone = tokyo
        app.host.refresh()
        app.sync()

        #expect(app.model.day.date == oct7 && app.model.day.timeZoneIdentifier == "Asia/Tokyo")
        #expect(app.model.draft == "rice")
        #expect(app.host.today.date == oct8)
    }
}
