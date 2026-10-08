import Foundation
import Observation

/// Something that can hold work the user has not saved, reported by date.
///
/// The day screen never leaves such a date by itself, so every feature with drafts registers one.
@MainActor
public protocol UnsavedWorkSource: AnyObject {
    var datesWithUnsavedWork: Set<LocalDate> { get }
}

extension FoodDrafts: UnsavedWorkSource {}

/// What can change the day on screen from outside the user's own taps.
public enum DayEvent: Sendable {
    /// The calendar day, the time zone, or the clock itself changed.
    case clockChanged
    case enteredBackground
    case becameActive
}

/// The state that spans features on the day screen: which date is showing, and what is unsaved on any date.
///
/// Every clock and lifecycle transition enters through `handle(_:)`, so the date on screen and the unsaved
/// work it depends on are always consulted together. The app target supplies the clock and the system
/// events; everything else is here so tests can drive the same paths with fakes.
@MainActor
public final class DaySession {
    public let host: DayHostModel
    public let foodDrafts: FoodDrafts
    private let sources: UnsavedWorkSources

    public init(
        clock: @escaping () -> Date = Date.init,
        timeZone: @escaping () -> TimeZone = { TimeZone.autoupdatingCurrent }
    ) {
        let foodDrafts = FoodDrafts()
        let sources = UnsavedWorkSources()
        sources.add(foodDrafts)
        self.foodDrafts = foodDrafts
        self.sources = sources
        host = DayHostModel(clock: clock, timeZone: timeZone, unsavedWork: { sources.dates })
    }

    /// Adds a feature's unsaved work to what the day screen protects.
    public func register(_ source: any UnsavedWorkSource) {
        sources.add(source)
    }

    public func handle(_ event: DayEvent) {
        switch event {
        case .clockChanged: host.refresh()
        case .enteredBackground: host.wentToBackground()
        case .becameActive: host.becameActive()
        }
    }

    /// Builds the food model for `day`, sharing this session's drafts.
    public func makeFoodLogModel(for day: Day, store: DayStore, matcher: FoodMatcher) -> FoodLogModel {
        FoodLogModel(day: day, store: store, matcher: matcher, drafts: foodDrafts)
    }
}

@MainActor
private final class UnsavedWorkSources {
    private var sources: [any UnsavedWorkSource] = []

    func add(_ source: any UnsavedWorkSource) {
        sources.append(source)
    }

    var dates: Set<LocalDate> {
        sources.reduce(into: []) { $0.formUnion($1.datesWithUnsavedWork) }
    }
}
