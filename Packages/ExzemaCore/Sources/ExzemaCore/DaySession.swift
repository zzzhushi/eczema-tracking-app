import Foundation
import Observation

/// What can change the day on screen from outside the user's own taps.
public enum DayEvent: Sendable {
    /// The calendar day, the time zone, or the clock itself changed.
    case clockChanged
    case enteredBackground
    case becameActive
}

/// The state that spans the day screen: which date is showing, and the food text not yet saved on any date.
///
/// Every clock and lifecycle transition enters through `handle(_:)`, so the date on screen and the unsaved
/// work it depends on are always consulted together. The app target supplies the clock and the system
/// events; everything else is here so tests can drive the same paths with fakes.
@MainActor
public final class DaySession {
    public let host: DayHostModel
    public let foodDrafts: FoodDrafts

    public init(
        clock: @escaping () -> Date = Date.init,
        timeZone: @escaping () -> TimeZone = { TimeZone.autoupdatingCurrent }
    ) {
        let foodDrafts = FoodDrafts()
        self.foodDrafts = foodDrafts
        host = DayHostModel(clock: clock, timeZone: timeZone, unsavedWork: { foodDrafts.datesWithUnsavedWork })
    }

    public func handle(_ event: DayEvent) {
        switch event {
        case .clockChanged: host.refresh()
        case .enteredBackground: host.wentToBackground()
        case .becameActive: host.becameActive()
        }
    }

    /// Builds the food model for `day`, sharing this session's drafts. The model is made for one day: the
    /// screen asks for a new one when the day changes, and the drafts carry the unsaved text across.
    public func makeFoodLogModel(for day: Day, store: DayStore, matcher: FoodMatcher) -> FoodLogModel {
        FoodLogModel(day: day, store: store, matcher: matcher, drafts: foodDrafts)
    }
}
