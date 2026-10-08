import GRDB

extension DayStore {
    /// The skin check-in slice's tables: areas and per-day ratings.
    static func registerV2Migration(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v2") { db in
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
                PRAGMA user_version = 2;
                """)
        }
    }
}
