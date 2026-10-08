import Foundation
import Observation

/// Which date the screen shows. Only the user, the Today button, and a return to the app after the date
/// changed move it; the clock and time zone never do.
///
/// "Today" is the phone's calendar date and stays live: it sets the caption and the limit of the forward
/// arrow. The model reads the clock only in `init`, `refresh()`, and the foreground transitions, so a screen
/// goes through `DaySession.handle(_:)` when the calendar day or time zone changes.
///
/// Every transition consults the same `unsavedWork` provider, which reports the dates that hold unsaved
/// work from any feature. The screen never leaves such a date by itself, and forward reaches it even when a
/// time zone change has made it a future date.
@MainActor
@Observable
public final class DayHostModel {
    public private(set) var now: Date
    public private(set) var timeZone: TimeZone
    public private(set) var shownDate: LocalDate
    /// What today was when the app last left the foreground, or nil while it is in front.
    private var dateWhenLeft: LocalDate?

    private let clock: () -> Date
    private let currentTimeZone: () -> TimeZone
    private let unsavedWork: @MainActor () -> Set<LocalDate>

    public init(
        clock: @escaping () -> Date = Date.init,
        timeZone: @escaping () -> TimeZone = { TimeZone.autoupdatingCurrent },
        unsavedWork: @escaping @MainActor () -> Set<LocalDate> = { [] }
    ) {
        self.clock = clock
        self.currentTimeZone = timeZone
        self.unsavedWork = unsavedWork
        let now = clock()
        let zone = timeZone()
        self.now = now
        self.timeZone = zone
        shownDate = Day(loggedAt: now, in: zone).date
    }

    public var today: Day { Day(loggedAt: now, in: timeZone) }

    /// The day on screen, logged in the phone's current time zone.
    public var day: Day { Day(date: shownDate, timeZoneIdentifier: timeZone.identifier) }

    public var isShowingToday: Bool { shownDate == today.date }
    /// True only for a date a time zone change made a future day while it holds unsaved work.
    public var isAfterToday: Bool { shownDate > today.date }
    public var canGoForward: Bool { shownDate < forwardLimit }
    /// How many days before today the screen is; zero on today.
    public var daysBack: Int { max(0, today.date.days(from: shownDate)) }

    public func goBack() {
        shownDate = shownDate.adding(days: -1)
    }

    /// Does nothing on today, so a future day is never reachable, unless it holds unsaved work.
    public func goForward() {
        guard canGoForward else { return }
        shownDate = shownDate.adding(days: 1)
    }

    public func goToToday() {
        shownDate = today.date
    }

    /// Shows `date` if it can be opened: today or earlier, or a later date that holds unsaved work.
    /// Returns whether the screen moved.
    @discardableResult
    public func show(_ date: LocalDate) -> Bool {
        guard canShow(date) else { return false }
        shownDate = date
        return true
    }

    /// Whether `show(_:)` would open `date`: today or earlier, or a later date that holds unsaved work.
    public func canShow(_ date: LocalDate) -> Bool { date <= forwardLimit }

    /// The latest date `show(_:)` opens, so a screen that lists dates can reach every one of them.
    public var latestShowableDate: LocalDate { forwardLimit }

    /// Re-reads the clock and time zone. The date on screen stays, except that a date a time zone change
    /// has made a future day moves back to today when it holds no unsaved work.
    func refresh() {
        now = clock()
        timeZone = currentTimeZone()
        if shownDate > today.date, !hasUnsavedWork(on: shownDate) { shownDate = today.date }
    }

    func wentToBackground() {
        refresh()
        dateWhenLeft = today.date
    }

    /// Opens today when the date changed while the app was away and the day on screen has no unsaved work. A
    /// date that changed while the app was in front never moves the screen.
    func becameActive() {
        let before = dateWhenLeft
        dateWhenLeft = nil
        refresh()
        guard let before, before != today.date, !hasUnsavedWork(on: shownDate) else { return }
        shownDate = today.date
    }

    private func hasUnsavedWork(on date: LocalDate) -> Bool { unsavedWork().contains(date) }

    /// The latest date forward may reach: today, or a later date that holds unsaved work.
    private var forwardLimit: LocalDate { max(today.date, unsavedWork().max() ?? today.date) }
}
