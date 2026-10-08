import Foundation
import GRDB

/// A body region whose skin is rated separately.
public struct Area: Hashable, Sendable {
    public let id: String
    public let name: String
}

public enum RatingKind: Sendable {
    case feel
    case look

    fileprivate var column: String {
        switch self {
        case .feel: "feel"
        case .look: "look"
        }
    }
}

/// An area's ratings for one day; a rating the user never gave is nil, which means unknown.
public struct CheckIn: Equatable, Sendable {
    public let date: LocalDate
    public let areaID: String
    public let feel: Int?
    public let look: Int?
    public let updatedAt: Date
}

public enum CheckInError: Error, Equatable {
    case ratingOutOfRange(Int)
    case unreadableTimestamp(String)
}

extension DayStore {
    /// The scale both ratings use.
    public static let ratingScale = 0...10

    /// Return the areas shown in the check-in, in display order.
    public func activeAreas() throws -> [Area] {
        try database.read { db in
            try Row.fetchAll(db, sql: "SELECT id, name FROM area WHERE isActive = 1 ORDER BY sortOrder").map {
                Area(id: $0["id"], name: $0["name"])
            }
        }
    }

    /// Return the check-ins recorded for `date`; an area with no row is unknown. Reading never creates a day.
    public func checkIns(on date: LocalDate) throws -> [CheckIn] {
        try database.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT check_in.areaId, feel, look, updatedAt FROM check_in
                JOIN area ON area.id = check_in.areaId
                WHERE dayDate = ? ORDER BY area.sortOrder
                """, arguments: [date.isoString])
            return try rows.map { row in
                let stamp: String = row["updatedAt"]
                guard let updatedAt = Self.parseTimestamp(stamp) else { throw CheckInError.unreadableTimestamp(stamp) }
                return CheckIn(date: date, areaID: row["areaId"], feel: row["feel"], look: row["look"], updatedAt: updatedAt)
            }
        }
    }

    /// Set one rating for an area, or clear it with nil, keeping only the latest value.
    ///
    /// The first rating of a day creates the day in `day`'s time zone. Clearing a rating that was never given
    /// writes nothing. A value outside `ratingScale` or an unknown area throws and writes nothing.
    public func setRating(
        _ kind: RatingKind, to value: Int?, area: String, on day: Day, at instant: Date = Date()
    ) throws {
        if let value, !Self.ratingScale.contains(value) { throw CheckInError.ratingOutOfRange(value) }
        let column = kind.column
        let stamp = Self.formatTimestamp(instant)
        try database.write { db in
            if let value {
                try db.execute(
                    sql: "INSERT OR IGNORE INTO day (date, timeZoneIdentifier) VALUES (?, ?)",
                    arguments: [day.date.isoString, day.timeZoneIdentifier]
                )
                try db.execute(sql: """
                    INSERT INTO check_in (dayDate, areaId, \(column), updatedAt) VALUES (?, ?, ?, ?)
                    ON CONFLICT (dayDate, areaId) DO UPDATE SET \(column) = excluded.\(column), updatedAt = excluded.updatedAt
                    """, arguments: [day.date.isoString, area, value, stamp])
            } else {
                try db.execute(
                    sql: "UPDATE check_in SET \(column) = NULL, updatedAt = ? WHERE dayDate = ? AND areaId = ?",
                    arguments: [stamp, day.date.isoString, area]
                )
            }
        }
        Log.checkIn.notice("checkin.rated", public: ["cleared": .bool(value == nil)])
    }

    static func formatTimestamp(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    static func parseTimestamp(_ text: String) -> Date? {
        try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}
