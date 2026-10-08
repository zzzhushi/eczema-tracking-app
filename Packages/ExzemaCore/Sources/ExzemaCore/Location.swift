import Foundation
import GRDB

/// A position in degrees, as reported by the phone before it is rounded for storage.
public struct Coordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

/// A stored position, rounded to 0.1° (about 11 km) and counted in whole tenths of a degree.
public struct LocationCapture: Equatable, Sendable {
    public let id: Int
    public let capturedAt: Date
    public let localDate: LocalDate
    public let timeZoneIdentifier: String
    public let latitudeTenths: Int
    public let longitudeTenths: Int
    /// The city the rounded position falls in, or nil until a lookup has succeeded.
    public let placeName: String?
}

/// The places recorded for one date, for display.
public struct DayPlaces: Equatable, Sendable {
    /// Distinct place names in the order they were first visited that day.
    public let names: [String]
    /// How many locations were captured that day, named or not.
    public let captureCount: Int

    public init(names: [String], captureCount: Int) {
        self.names = names
        self.captureCount = captureCount
    }
}

/// Names a rounded position, or returns nil when no name is available, such as without a network.
public protocol PlaceNaming: Sendable {
    func placeName(for coordinate: Coordinate) async -> String?
}

/// A rounded position, in whole tenths of a degree.
struct PlaceKey: Equatable {
    let latitudeTenths: Int
    let longitudeTenths: Int
}

/// Supplies one current location, or nil when permission is missing or no fix comes back.
public protocol LocationSource: Sendable {
    func currentLocation() async -> Coordinate?
}

extension DayStore {
    /// Store `coordinate` rounded to 0.1°, filed under the local date at `instant` in `timeZone`.
    ///
    /// A coordinate outside the valid range is dropped. Captures never create or reference a day. Returns whether
    /// a row was written.
    @discardableResult
    public func addLocationCapture(_ coordinate: Coordinate, at instant: Date, in timeZone: TimeZone) throws -> Bool {
        guard coordinate.isValid else { return false }
        let localDate = Day(loggedAt: instant, in: timeZone).date
        try database.write { db in
            try db.execute(sql: """
                INSERT INTO location_capture (capturedAt, localDate, timeZoneIdentifier, latitudeTenths, longitudeTenths)
                VALUES (?, ?, ?, ?, ?)
                """, arguments: [
                    Self.formatTimestamp(instant), localDate.isoString, timeZone.identifier,
                    Int((coordinate.latitude * 10).rounded()), Int((coordinate.longitude * 10).rounded()),
                ])
        }
        return true
    }

    /// Return when the newest capture was taken, or nil when there is none.
    public func latestLocationCaptureTime() throws -> Date? {
        try database.read { db in
            guard let stamp = try String.fetchOne(db, sql: "SELECT MAX(capturedAt) FROM location_capture") else {
                return nil
            }
            guard let date = Self.parseTimestamp(stamp) else { throw CheckInError.unreadableTimestamp(stamp) }
            return date
        }
    }

    /// Return every capture, oldest first.
    public func locationCaptures() throws -> [LocationCapture] {
        try database.read { db in
            try Row.fetchAll(db, sql: """
                SELECT id, capturedAt, localDate, timeZoneIdentifier, latitudeTenths, longitudeTenths, placeName
                FROM location_capture ORDER BY capturedAt, id
                """).map { row in
                let stamp: String = row["capturedAt"]
                let dateText: String = row["localDate"]
                guard let capturedAt = Self.parseTimestamp(stamp) else { throw CheckInError.unreadableTimestamp(stamp) }
                guard let localDate = LocalDate(isoString: dateText) else { throw DayStoreError.unreadableDate(dateText) }
                return LocationCapture(
                    id: row["id"], capturedAt: capturedAt, localDate: localDate,
                    timeZoneIdentifier: row["timeZoneIdentifier"],
                    latitudeTenths: row["latitudeTenths"], longitudeTenths: row["longitudeTenths"],
                    placeName: row["placeName"]
                )
            }
        }
    }
}

extension DayStore {
    /// Name one capture.
    public func setPlaceName(_ name: String, forCaptureID id: Int) throws {
        try database.write {
            try $0.execute(sql: "UPDATE location_capture SET placeName = ? WHERE id = ?", arguments: [name, id])
        }
    }

    /// Return the places of the newest captures that have no name, one per distinct rounded position.
    func unnamedPlaceKeys(limit: Int) throws -> [PlaceKey] {
        try database.read { db in
            try Row.fetchAll(db, sql: """
                SELECT latitudeTenths, longitudeTenths FROM location_capture WHERE placeName IS NULL
                GROUP BY latitudeTenths, longitudeTenths ORDER BY MAX(capturedAt) DESC LIMIT ?
                """, arguments: [limit]).map {
                PlaceKey(latitudeTenths: $0["latitudeTenths"], longitudeTenths: $0["longitudeTenths"])
            }
        }
    }

    /// Return a name already stored for the same rounded position, so one lookup serves every capture there.
    func knownPlaceName(at key: PlaceKey) throws -> String? {
        try database.read {
            try String.fetchOne($0, sql: """
                SELECT placeName FROM location_capture
                WHERE latitudeTenths = ? AND longitudeTenths = ? AND placeName IS NOT NULL LIMIT 1
                """, arguments: [key.latitudeTenths, key.longitudeTenths])
        }
    }

    /// Name every unnamed capture at `key`; return how many were named.
    func nameUnnamedCaptures(at key: PlaceKey, as name: String) throws -> Int {
        try database.write { db in
            try db.execute(sql: """
                UPDATE location_capture SET placeName = ?
                WHERE placeName IS NULL AND latitudeTenths = ? AND longitudeTenths = ?
                """, arguments: [name, key.latitudeTenths, key.longitudeTenths])
            return db.changesCount
        }
    }

    /// Return the places captured on `date`; no capture means nothing is known, not that no place was visited.
    public func places(on date: LocalDate) throws -> DayPlaces {
        try database.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT placeName FROM location_capture WHERE localDate = ? ORDER BY capturedAt, id
                """, arguments: [date.isoString])
            var names: [String] = []
            for row in rows {
                if let name: String = row["placeName"], !names.contains(name) { names.append(name) }
            }
            return DayPlaces(names: names, captureCount: rows.count)
        }
    }
}

/// Records a location when the app becomes active, at most once per hour.
public struct LocationRecorder: Sendable {
    /// Seconds a stored capture suppresses the next one.
    public static let minimumInterval: TimeInterval = 3_600

    private let store: DayStore
    private let source: any LocationSource
    private let now: @Sendable () -> Date
    private let timeZone: @Sendable () -> TimeZone
    private let places: (any PlaceNaming)?

    /// Most distinct rounded positions looked up in one pass.
    static let placeLookupsPerPass = 3

    public init(
        store: DayStore,
        source: any LocationSource,
        now: @escaping @Sendable () -> Date = { Date() },
        timeZone: @escaping @Sendable () -> TimeZone = { .autoupdatingCurrent },
        places: (any PlaceNaming)? = nil
    ) {
        self.store = store
        self.source = source
        self.now = now
        self.timeZone = timeZone
        self.places = places
    }

    /// Name captures that have no place name yet; return how many were named.
    ///
    /// A position already named is reused without a lookup, and a lookup sends only the rounded position. A
    /// lookup that returns nothing leaves its captures unnamed so a later pass can try again.
    @discardableResult
    public func fillMissingPlaceNames() async -> Int {
        guard let places else { return 0 }
        var named = 0
        do {
            for key in try store.unnamedPlaceKeys(limit: Self.placeLookupsPerPass) {
                var name = try store.knownPlaceName(at: key)
                if name == nil {
                    let rounded = Coordinate(latitude: Double(key.latitudeTenths) / 10, longitude: Double(key.longitudeTenths) / 10)
                    name = await places.placeName(for: rounded)?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard let name, !name.isEmpty else { continue }
                named += try store.nameUnnamedCaptures(at: key, as: String(name.prefix(100)))
            }
        } catch {
            Log.environment.error("place.nameFailed", private: ["error": String(describing: error)])
        }
        Log.environment.notice("place.named", public: ["named": .int(named)])
        return named
    }

    /// Store a location unless the newest capture is less than an hour old; return whether one was stored.
    ///
    /// The hour runs from the newest stored capture, so an unavailable location does not start a wait. A clock that
    /// moved backwards past the newest capture counts as due.
    @discardableResult
    public func captureIfDue() async -> Bool {
        let instant = now()
        do {
            if let latest = try store.latestLocationCaptureTime() {
                let age = instant.timeIntervalSince(latest)
                guard age >= Self.minimumInterval || age < 0 else { return false }
            }
            guard let coordinate = await source.currentLocation() else {
                Log.environment.notice("location.unavailable")
                return false
            }
            let stored = try store.addLocationCapture(coordinate, at: instant, in: timeZone())
            Log.environment.notice("location.captured", public: ["stored": .bool(stored)])
            return stored
        } catch {
            Log.environment.error("location.captureFailed", private: ["error": String(describing: error)])
            return false
        }
    }
}
