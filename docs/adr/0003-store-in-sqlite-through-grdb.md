# Store days in SQLite through GRDB

**Status**: accepted

## Context

The store must carry an explicit schema version, read back identically after a reload, and migrate between versions without wiping data from the first slice that holds real logs. The testing rules want one committed fixture store per schema version, run on a Mac and in CI without a simulator. The choices were SwiftData, Core Data, and SQLite through GRDB, a third-party Swift package.

SwiftData and Core Data keep the schema version implicit in the model types, and a fixture store per version needs every old model kept in the code. GRDB's migrations are named, ordered SQL steps, the version is stored in the file's `user_version`, and a fixture is a plain `.sqlite` file. A spike showed GRDB 7.11.1 builds for iOS 27 and runs its tests on macOS under Xcode 27.

## Decision

The structured store is a SQLite file written through GRDB inside the `ExzemaCore` package, versioned with `user_version` and migrated by registered migrations. A store written by a newer schema is refused and left untouched. The store's directory is excluded from device and iCloud backups.

## Consequences

The project carries one third-party dependency, which must keep building on each new Xcode. Records are mapped by hand. If GRDB stops building or is abandoned, the data is an ordinary SQLite file that any other layer can read, so the cost of leaving is rewriting the access code, not migrating the data.
