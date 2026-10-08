import Foundation
import Observation

/// Which day the screen shows: today, or a day the user stepped back to.
///
/// The model only reads the clock and time zone in `init` and `refresh()`, so a screen must call `refresh()`
/// when the calendar day changes, the time zone changes, or the app returns to the foreground. Today follows
/// the clock; a day the user stepped back to stays put. Never a day after today.
@MainActor
@Observable
public final class DayHostModel {
    public private(set) var now: Date
    public private(set) var timeZone: TimeZone
    private var pinned: LocalDate?

    private let clock: () -> Date
    private let currentTimeZone: () -> TimeZone

    public init(
        clock: @escaping () -> Date = Date.init,
        timeZone: @escaping () -> TimeZone = { TimeZone.autoupdatingCurrent }
    ) {
        self.clock = clock
        self.currentTimeZone = timeZone
        now = clock()
        self.timeZone = timeZone()
    }

    public var today: Day { Day(loggedAt: now, in: timeZone) }

    /// The day on screen, logged in the phone's current time zone.
    public var day: Day {
        pinned.map { Day(date: $0, timeZoneIdentifier: timeZone.identifier) } ?? today
    }

    public var isToday: Bool { pinned == nil }
    public var canGoForward: Bool { pinned != nil }
    public var daysBack: Int { today.date.days(from: day.date) }

    public func goBack() {
        pinned = day.date.adding(days: -1)
    }

    /// Does nothing on today. Stepping forward onto today goes back to following the clock.
    public func goForward() {
        guard let pinned else { return }
        let next = pinned.adding(days: 1)
        self.pinned = next < today.date ? next : nil
    }

    public func refresh() {
        now = clock()
        timeZone = currentTimeZone()
        if let pinned, pinned >= today.date { self.pinned = nil }
    }
}
