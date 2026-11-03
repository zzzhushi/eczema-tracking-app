import GRDB

extension DayStore {
    /// The photos slice's tables: the places a photo can be taken of, and the photos filed under days.
    static func registerV4Migration(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v4") { db in
            try db.execute(sql: """
                CREATE TABLE photo_slot (
                    id TEXT PRIMARY KEY NOT NULL,
                    areaId TEXT NOT NULL REFERENCES area(id),
                    name TEXT NOT NULL,
                    sortOrder INTEGER NOT NULL
                );
                INSERT INTO photo_slot (id, areaId, name, sortOrder) VALUES
                    ('face', 'face', 'Face', 0),
                    ('left-hand', 'hands', 'Left hand', 1),
                    ('right-hand', 'hands', 'Right hand', 2);
                CREATE TABLE photo (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    dayDate TEXT NOT NULL REFERENCES day(date) ON DELETE CASCADE,
                    slotId TEXT NOT NULL REFERENCES photo_slot(id),
                    kind TEXT NOT NULL CHECK (kind IN ('photo', 'closeUp')),
                    camera TEXT NOT NULL CHECK (camera IN ('front', 'back')),
                    takenAt TEXT NOT NULL,
                    timeZoneIdentifier TEXT NOT NULL,
                    fileName TEXT NOT NULL UNIQUE
                );
                CREATE INDEX photo_dayDate ON photo (dayDate);
                PRAGMA user_version = 4;
                """)
        }
    }
}
