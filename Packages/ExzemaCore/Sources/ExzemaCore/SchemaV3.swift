import GRDB

extension DayStore {
    /// The skin check-in slice's tables: areas, per-day ratings, and location captures.
    static func registerV3Migration(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v3") { db in
            try db.execute(sql: """
                CREATE TABLE area (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    isActive INTEGER NOT NULL,
                    sortOrder INTEGER NOT NULL
                );
                INSERT INTO area (id, name, isActive, sortOrder) VALUES ('face', 'Face', 1, 0), ('hands', 'Hands', 1, 1);
                CREATE TABLE check_in (
                    dayDate TEXT NOT NULL REFERENCES day(date) ON DELETE CASCADE,
                    areaId TEXT NOT NULL REFERENCES area(id),
                    feel INTEGER CHECK (feel BETWEEN 0 AND 10),
                    look INTEGER CHECK (look BETWEEN 0 AND 10),
                    updatedAt TEXT NOT NULL,
                    PRIMARY KEY (dayDate, areaId)
                );
                CREATE TABLE location_capture (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    capturedAt TEXT NOT NULL,
                    localDate TEXT NOT NULL,
                    timeZoneIdentifier TEXT NOT NULL,
                    latitudeTenths INTEGER NOT NULL,
                    longitudeTenths INTEGER NOT NULL
                );
                CREATE INDEX location_capture_capturedAt ON location_capture (capturedAt);
                PRAGMA user_version = 3;
                """)
        }
    }
}
