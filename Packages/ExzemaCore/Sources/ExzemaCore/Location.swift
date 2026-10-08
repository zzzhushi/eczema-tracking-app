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
    public let capturedAt: Date
    public let localDate: LocalDate
    public let timeZoneIdentifier: String
    public let latitudeTenths: Int
    public let longitudeTenths: Int
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
                SELECT capturedAt, localDate, timeZoneIdentifier, latitudeTenths, longitudeTenths
                FROM location_capture ORDER BY capturedAt, id
                """).map { row in
                let stamp: String = row["capturedAt"]
                let dateText: String = row["localDate"]
                guard let capturedAt = Self.parseTimestamp(stamp) else { throw CheckInError.unreadableTimestamp(stamp) }
                guard let localDate = LocalDate(isoString: dateText) else { throw DayStoreError.unreadableDate(dateText) }
                return LocationCapture(
                    capturedAt: capturedAt, localDate: localDate, timeZoneIdentifier: row["timeZoneIdentifier"],
                    latitudeTenths: row["latitudeTenths"], longitudeTenths: row["longitudeTenths"]
                )
            }
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

    public init(
        store: DayStore,
        source: any LocationSource,
        now: @escaping @Sendable () -> Date = { Date() },
        timeZone: @escaping @Sendable () -> TimeZone = { .current }
    ) {
        self.store = store
        self.source = source
        self.now = now
        self.timeZone = timeZone
    }

    /// Store a location unless the newest capture is no more than an hour old; return whether one was stored.
    ///
    /// The hour runs from the newest stored capture, so an unavailable location does not start a wait. A clock that
    /// moved backwards past the newest capture counts as due.
    @discardableResult
    public func captureIfDue() async -> Bool {
        let instant = now()
        do {
            if let latest = try store.latestLocationCaptureTime() {
                let age = instant.timeIntervalSince(latest)
                guard age > Self.minimumInterval || age < 0 else { return false }
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
