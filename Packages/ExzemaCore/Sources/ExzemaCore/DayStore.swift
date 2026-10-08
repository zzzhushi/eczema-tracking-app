import Foundation
import GRDB

public enum DayStoreError: Error, Equatable {
    /// The store was written by a newer app version; opening it could lose data, so it is left untouched.
    case newerSchema(found: Int)
    case unreadableDate(String)
    /// A food line must hold at least one item, so a logged day always has food in it.
    case noItems
    case unknownFoodLine
    case unknownFoodItem
}

/// The on-device store of days, versioned by SQLite's `user_version`.
public final class DayStore: Sendable {
    public static let currentSchemaVersion = 2

    let database: DatabaseQueue
    let log: CategoryLogger

    /// Open the store at `url`, creating or migrating it to the current schema.
    ///
    /// The store's directory must be dedicated to it: the directory is excluded from backup so that files the
    /// database creates beside the store are excluded too.
    /// Throws `DayStoreError.newerSchema` without writing anything when the file comes from a newer schema.
    public init(at url: URL, log: CategoryLogger = Log.storage) throws {
        self.log = log
        database = try DatabaseQueue(path: url.path)

        let found = try database.read { try Int.fetchOne($0, sql: "PRAGMA user_version") ?? 0 }
        guard found <= Self.currentSchemaVersion else {
            try database.close()
            log.fault("store.refused", public: ["found": .int(found), "supported": .int(Self.currentSchemaVersion)])
            throw DayStoreError.newerSchema(found: found)
        }

        try Self.migrator.migrate(database)
        try Self.excludeFromBackup(url)
        try Self.excludeFromBackup(url.deletingLastPathComponent())
        log.notice("store.opened", public: ["schemaVersion": .int(Self.currentSchemaVersion)])
    }

    public func schemaVersion() throws -> Int {
        try database.read { try Int.fetchOne($0, sql: "PRAGMA user_version") ?? 0 }
    }

    /// Record `day`; a date already stored keeps the time zone it was first logged in.
    public func save(_ day: Day) throws {
        let inserted = try database.write { db -> Bool in
            try db.execute(
                sql: "INSERT OR IGNORE INTO day (date, timeZoneIdentifier) VALUES (?, ?)",
                arguments: [day.date.isoString, day.timeZoneIdentifier]
            )
            return db.changesCount > 0
        }
        log.notice("day.saved", public: ["inserted": .bool(inserted)], private: ["date": day.date.isoString])
    }

    /// Remove the day with `date`; a date that was never saved is left alone.
    public func delete(_ date: LocalDate) throws {
        try database.write { try $0.execute(sql: "DELETE FROM day WHERE date = ?", arguments: [date.isoString]) }
    }

    /// Remove every day. The store keeps its schema and stays usable.
    public func deleteAll() throws {
        let count = try database.write { db -> Int in
            try db.execute(sql: "DELETE FROM day")
            return db.changesCount
        }
        log.notice("days.cleared", public: ["count": .int(count)])
    }

    /// Return every stored day, newest date first.
    public func days() throws -> [Day] {
        try database.read { db in
            try Row.fetchAll(db, sql: "SELECT date, timeZoneIdentifier FROM day ORDER BY date DESC").map { row in
                let text: String = row["date"]
                guard let date = LocalDate(isoString: text) else { throw DayStoreError.unreadableDate(text) }
                return Day(date: date, timeZoneIdentifier: row["timeZoneIdentifier"])
            }
        }
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE day (
                    date TEXT PRIMARY KEY NOT NULL,
                    timeZoneIdentifier TEXT NOT NULL
                );
                PRAGMA user_version = 1;
                """)
        }
        migrator.registerMigration("v2") { db in
            try db.execute(sql: """
                CREATE TABLE food_line (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    date TEXT NOT NULL REFERENCES day(date) ON DELETE CASCADE,
                    text TEXT NOT NULL,
                    timeZoneIdentifier TEXT NOT NULL
                );
                CREATE INDEX food_line_date ON food_line(date);
                CREATE TABLE food_item (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    lineId INTEGER NOT NULL REFERENCES food_line(id) ON DELETE CASCADE,
                    position INTEGER NOT NULL,
                    text TEXT NOT NULL,
                    foodID TEXT
                );
                CREATE INDEX food_item_line ON food_item(lineId);
                PRAGMA user_version = 2;
                """)
        }
        return migrator
    }

    /// The store never reaches device or iCloud backups; the user's Mac is the only backup destination.
    private static func excludeFromBackup(_ url: URL) throws {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}
