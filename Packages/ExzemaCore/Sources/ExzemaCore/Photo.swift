import Foundation
import GRDB

/// Whether a photo is a framing photo of a slot or an optional close-up of a patch of skin.
public enum PhotoKind: String, Sendable {
    case photo
    case closeUp
}

/// Which camera took the photo; the two are not comparable, so the camera is kept with each photo.
public enum PhotoCamera: String, Sendable {
    case front
    case back
}

extension PhotoCamera {
    /// Read the camera from an EXIF lens model such as "iPhone 15 Pro front camera 2.69mm f/1.9"; nil when it names neither.
    public init?(lensModel: String?) {
        guard let lensModel = lensModel?.lowercased() else { return nil }
        if lensModel.contains("front") {
            self = .front
        } else if lensModel.contains("back") {
            self = .back
        } else {
            return nil
        }
    }
}

/// A place a photo can be taken of, such as the face or the left hand.
public struct PhotoSlot: Hashable, Sendable {
    public let id: String
    public let areaID: String
    public let name: String

    /// The camera the capture sheet opens on: the front camera shows the user their face while framing it.
    public var presetCamera: PhotoCamera { areaID == "face" ? .front : .back }

    /// Whether the slot takes an optional close-up of a patch of skin besides its framing photos.
    public var offersCloseUp: Bool { areaID == "face" }
}

/// A photo's record. The image itself lives in a file named `fileName`, outside the store.
public struct StoredPhoto: Equatable, Sendable {
    public let id: Int64
    /// The day the photo is filed under, which can be the day before `takenAt`.
    public let date: LocalDate
    public let slotID: String
    public let kind: PhotoKind
    public let camera: PhotoCamera
    public let takenAt: Date
    public let timeZoneIdentifier: String
    public let fileName: String
}

public enum PhotoError: Error, Equatable {
    case unknownSlot(String)
    case closeUpNotOffered(String)
    case cannotFile(on: LocalDate)
    case unreadableRecord(String)
}

/// The days a new photo may be filed under.
public enum PhotoFiling {
    /// A photo belongs to today, or to yesterday when it is taken after midnight. Nothing earlier or later.
    public static func canFile(on date: LocalDate, today: LocalDate) -> Bool {
        date == today || date == today.adding(days: -1)
    }
}

extension DayStore {
    /// Return the slots photos can be taken of, in display order.
    public func photoSlots() throws -> [PhotoSlot] {
        try database.read { db in
            try Row.fetchAll(db, sql: "SELECT id, areaId, name FROM photo_slot ORDER BY sortOrder").map {
                PhotoSlot(id: $0["id"], areaID: $0["areaId"], name: $0["name"])
            }
        }
    }

    /// Record a photo whose image is already stored under `fileName`, filed under `filedOn`.
    ///
    /// The day is created in `timeZone` if it has no row yet. Throws `PhotoError.cannotFile` unless `filedOn` is
    /// `today` or the day before, `PhotoError.unknownSlot` for a slot that does not exist, and
    /// `PhotoError.closeUpNotOffered` for a close-up of a slot that takes none; each writes nothing.
    @discardableResult
    public func addPhoto(
        fileName: String, slot: String, kind: PhotoKind, camera: PhotoCamera,
        takenAt: Date, in timeZone: TimeZone, filedOn: LocalDate, today: LocalDate
    ) throws -> StoredPhoto {
        guard PhotoFiling.canFile(on: filedOn, today: today) else { throw PhotoError.cannotFile(on: filedOn) }
        let stamp = Self.formatTimestamp(takenAt)
        let id = try database.write { db -> Int64 in
            guard let row = try Row.fetchOne(db, sql: "SELECT id, areaId, name FROM photo_slot WHERE id = ?", arguments: [slot])
            else { throw PhotoError.unknownSlot(slot) }
            let found = PhotoSlot(id: row["id"], areaID: row["areaId"], name: row["name"])
            if kind == .closeUp, !found.offersCloseUp { throw PhotoError.closeUpNotOffered(slot) }
            try db.execute(
                sql: "INSERT OR IGNORE INTO day (date, timeZoneIdentifier) VALUES (?, ?)",
                arguments: [filedOn.isoString, timeZone.identifier]
            )
            try db.execute(sql: """
                INSERT INTO photo (dayDate, slotId, kind, camera, takenAt, timeZoneIdentifier, fileName)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [filedOn.isoString, slot, kind.rawValue, camera.rawValue, stamp, timeZone.identifier, fileName])
            return db.lastInsertedRowID
        }
        Log.photos.notice("photo.added", public: ["closeUp": .bool(kind == .closeUp), "frontCamera": .bool(camera == .front)])
        return StoredPhoto(
            id: id, date: filedOn, slotID: slot, kind: kind, camera: camera,
            takenAt: takenAt, timeZoneIdentifier: timeZone.identifier, fileName: fileName
        )
    }

    /// Return the photos filed under `date`, by slot order and then capture time. Reading never creates a day.
    public func photos(on date: LocalDate) throws -> [StoredPhoto] {
        try database.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT photo.id, slotId, kind, camera, takenAt, photo.timeZoneIdentifier, fileName FROM photo
                JOIN photo_slot ON photo_slot.id = photo.slotId
                WHERE dayDate = ? ORDER BY photo_slot.sortOrder, takenAt, photo.id
                """, arguments: [date.isoString])
            return try rows.map { row in
                let stamp: String = row["takenAt"]
                let kindText: String = row["kind"]
                let cameraText: String = row["camera"]
                guard let takenAt = Self.parseTimestamp(stamp) else { throw PhotoError.unreadableRecord(stamp) }
                guard let kind = PhotoKind(rawValue: kindText) else { throw PhotoError.unreadableRecord(kindText) }
                guard let camera = PhotoCamera(rawValue: cameraText) else { throw PhotoError.unreadableRecord(cameraText) }
                return StoredPhoto(
                    id: row["id"], date: date, slotID: row["slotId"], kind: kind, camera: camera,
                    takenAt: takenAt, timeZoneIdentifier: row["timeZoneIdentifier"], fileName: row["fileName"]
                )
            }
        }
    }

    /// Remove a photo's record and return the name of its image file, which the caller removes; nil when no such photo.
    /// The day stays even when its last photo goes.
    public func deletePhoto(id: Int64) throws -> String? {
        let fileName = try database.write { db -> String? in
            guard let name = try String.fetchOne(db, sql: "SELECT fileName FROM photo WHERE id = ?", arguments: [id])
            else { return nil }
            try db.execute(sql: "DELETE FROM photo WHERE id = ?", arguments: [id])
            return name
        }
        if fileName != nil { Log.photos.notice("photo.deleted") }
        return fileName
    }

    /// Return the image file names of every stored photo, so files can be removed before rows are deleted in bulk.
    public func allPhotoFileNames() throws -> [String] {
        try database.read { try String.fetchAll($0, sql: "SELECT fileName FROM photo") }
    }
}
