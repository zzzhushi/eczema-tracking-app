import GRDB

extension DayStore {
    /// Adds the place name a location capture is given once its rounded position has been looked up.
    static func registerV4Migration(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v4") { db in
            try db.execute(sql: """
                ALTER TABLE location_capture ADD COLUMN placeName TEXT;
                PRAGMA user_version = 4;
                """)
        }
    }
}
