import Foundation

/// Keeps each photo's record in the store and its image file together.
public final class PhotoLibrary: Sendable {
    private let store: DayStore
    private let files: PhotoFileStore

    public init(store: DayStore, files: PhotoFileStore) {
        self.store = store
        self.files = files
    }

    /// Store a captured image and record it under `filedOn`.
    ///
    /// The camera is read from `lensModel` when it names one, because the system sheet lets the user flip
    /// cameras; otherwise `presetCamera` is recorded. A failure at any step leaves neither a file nor a record.
    @discardableResult
    public func add(
        imageData: Data, slot: String, kind: PhotoKind, presetCamera: PhotoCamera, lensModel: String?,
        takenAt: Date, in timeZone: TimeZone, filedOn: LocalDate, today: LocalDate
    ) throws -> StoredPhoto {
        guard PhotoFiling.canFile(on: filedOn, today: today) else { throw PhotoError.cannotFile(on: filedOn) }
        let fileName = try files.save(imageData: imageData)
        do {
            return try store.addPhoto(
                fileName: fileName, slot: slot, kind: kind, camera: PhotoCamera(lensModel: lensModel) ?? presetCamera,
                takenAt: takenAt, in: timeZone, filedOn: filedOn, today: today
            )
        } catch {
            try? files.delete(fileName: fileName)
            throw error
        }
    }

    /// Remove a photo's record and its image file.
    public func delete(_ photo: StoredPhoto) throws {
        guard let fileName = try store.deletePhoto(id: photo.id) else { return }
        try files.delete(fileName: fileName)
    }

    /// Return the image files that no record names, sorted. Nothing is deleted: such a file can be left by an
    /// interrupted save, but it can also be the only copy of a photo whose record was lost with a reset or restored
    /// store, and a photo cannot be taken again.
    public func orphanFileNames() throws -> [String] {
        let recorded = Set(try store.allPhotoFileNames())
        return try files.fileNames().subtracting(recorded).sorted()
    }

    /// Remove a day with its photo records and their image files.
    public func deleteDay(_ date: LocalDate) throws {
        let names = try store.photos(on: date).map(\.fileName)
        try store.delete(date)
        for name in names { try files.delete(fileName: name) }
    }

    /// Remove every day with every photo record and image file.
    public func deleteAllDays() throws {
        let names = try store.allPhotoFileNames()
        try store.deleteAll()
        for name in names { try files.delete(fileName: name) }
    }
}
