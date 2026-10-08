import Foundation
import GRDB

public struct FoodLineID: Hashable, Sendable {
    public let rawValue: Int64

    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }
}

public struct FoodItemID: Hashable, Sendable {
    public let rawValue: Int64

    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }
}

/// A parsed item as stored: its match was fixed when the line was saved.
public struct StoredFoodItem: Equatable, Sendable {
    public let id: FoodItemID
    public let item: ParsedItem
}

/// One saved piece of typed food text with the items it was parsed into.
public struct FoodLine: Equatable, Sendable {
    public let id: FoodLineID
    /// The text as typed, kept so the line can be reopened and so history survives later catalog changes.
    /// Deleting an item rewrites it from the remaining items, so the text never names a deleted item.
    public let text: String
    public let timeZoneIdentifier: String
    public let items: [StoredFoodItem]
}

extension DayStore {
    /// Save a line of typed food on `day`, storing the day on its first write.
    ///
    /// Throws `DayStoreError.noItems`, storing nothing, when `items` is empty.
    @discardableResult
    public func addFoodLine(text: String, items: [ParsedItem], on day: Day) throws -> FoodLineID {
        guard !items.isEmpty else { throw DayStoreError.noItems }
        let id = try database.write { db -> FoodLineID in
            try db.execute(
                sql: "INSERT OR IGNORE INTO day (date, timeZoneIdentifier) VALUES (?, ?)",
                arguments: [day.date.isoString, day.timeZoneIdentifier]
            )
            try db.execute(
                sql: "INSERT INTO food_line (date, text, timeZoneIdentifier) VALUES (?, ?, ?)",
                arguments: [day.date.isoString, text, day.timeZoneIdentifier]
            )
            let id = FoodLineID(rawValue: db.lastInsertedRowID)
            try Self.insert(items, into: id, db)
            return id
        }
        log.notice("foodLine.added", public: ["items": .int(items.count)])
        return id
    }

    /// Replace a line's text and items, keeping its place and time zone.
    public func replaceFoodLine(_ id: FoodLineID, text: String, items: [ParsedItem]) throws {
        guard !items.isEmpty else { throw DayStoreError.noItems }
        try database.write { db in
            try db.execute(sql: "UPDATE food_line SET text = ? WHERE id = ?", arguments: [text, id.rawValue])
            guard db.changesCount > 0 else { throw DayStoreError.unknownFoodLine }
            try db.execute(sql: "DELETE FROM food_item WHERE lineId = ?", arguments: [id.rawValue])
            try Self.insert(items, into: id, db)
        }
        log.notice("foodLine.replaced", public: ["items": .int(items.count)])
    }

    public func deleteFoodLine(_ id: FoodLineID) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM food_line WHERE id = ?", arguments: [id.rawValue])
            guard db.changesCount > 0 else { throw DayStoreError.unknownFoodLine }
        }
        log.notice("foodLine.deleted")
    }

    /// Delete one item and rewrite its line's text from the items that remain, so reopening the line cannot
    /// bring the item back. The line goes with its last item, so no line is ever empty.
    public func deleteFoodItem(_ id: FoodItemID) throws {
        try database.write { db in
            guard let lineId = try Int64.fetchOne(db, sql: "SELECT lineId FROM food_item WHERE id = ?", arguments: [id.rawValue])
            else { throw DayStoreError.unknownFoodItem }
            try db.execute(sql: "DELETE FROM food_item WHERE id = ?", arguments: [id.rawValue])
            let remaining = try String.fetchAll(
                db,
                sql: "SELECT text FROM food_item WHERE lineId = ? ORDER BY position",
                arguments: [lineId]
            )
            if remaining.isEmpty {
                try db.execute(sql: "DELETE FROM food_line WHERE id = ?", arguments: [lineId])
            } else {
                try db.execute(
                    sql: "UPDATE food_line SET text = ? WHERE id = ?",
                    arguments: [remaining.joined(separator: ", "), lineId]
                )
            }
        }
        log.notice("foodItem.deleted")
    }

    /// Return the lines saved for `date` in the order they were saved. Reading never stores the day.
    public func foodLines(on date: LocalDate) throws -> [FoodLine] {
        try database.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT id, text, timeZoneIdentifier FROM food_line WHERE date = ? ORDER BY id",
                arguments: [date.isoString]
            ).map { line in
                let lineId: Int64 = line["id"]
                let items = try Row.fetchAll(
                    db,
                    sql: "SELECT id, text, foodID FROM food_item WHERE lineId = ? ORDER BY position",
                    arguments: [lineId]
                ).map { row -> StoredFoodItem in
                    let foodID: String? = row["foodID"]
                    return StoredFoodItem(
                        id: FoodItemID(rawValue: row["id"]),
                        item: ParsedItem(text: row["text"], resolution: foodID.map { .matched(foodID: $0) } ?? .unrecognized)
                    )
                }
                return FoodLine(id: FoodLineID(rawValue: lineId), text: line["text"], timeZoneIdentifier: line["timeZoneIdentifier"], items: items)
            }
        }
    }

    /// A day is logged when it has at least one food item; a day without one is unknown, never a day of eating nothing.
    public func isLogged(_ date: LocalDate) throws -> Bool {
        try database.read { db in
            try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS (SELECT 1 FROM food_item JOIN food_line ON food_line.id = food_item.lineId WHERE food_line.date = ?)",
                arguments: [date.isoString]
            ) ?? false
        }
    }

    private static func insert(_ items: [ParsedItem], into line: FoodLineID, _ db: Database) throws {
        for (position, item) in items.enumerated() {
            let foodID: String?
            switch item.resolution {
            case .matched(let id): foodID = id
            case .unrecognized: foodID = nil
            }
            try db.execute(
                sql: "INSERT INTO food_item (lineId, position, text, foodID) VALUES (?, ?, ?, ?)",
                arguments: [line.rawValue, position, item.text, foodID]
            )
        }
    }
}
