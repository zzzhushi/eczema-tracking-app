import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import ExzemaCore

@Suite("Photo library")
struct PhotoLibraryTests {
    private let directory: URL
    private let zone = TimeZone(identifier: "America/Los_Angeles")!
    private let tuesday = LocalDate(year: 2026, month: 10, day: 6)
    private let taken = Date(timeIntervalSince1970: 1_791_000_000)

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoLibraryTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func openLibrary() throws -> (PhotoLibrary, DayStore, PhotoFileStore) {
        let store = try DayStore(at: {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("store.sqlite")
        }())
        let files = try PhotoFileStore(directory: directory.appendingPathComponent("Photos", isDirectory: true))
        return (PhotoLibrary(store: store, files: files), store, files)
    }

    private func imageData() throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 300, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(red: 0.8, green: 0.5, blue: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func add(
        _ library: PhotoLibrary, slot: String = "face", kind: PhotoKind = .photo,
        preset: PhotoCamera = .front, lensModel: String? = nil, filedOn: LocalDate? = nil, today: LocalDate? = nil
    ) throws -> StoredPhoto {
        try library.add(
            imageData: imageData(), slot: slot, kind: kind, presetCamera: preset, lensModel: lensModel,
            takenAt: taken, in: zone, filedOn: filedOn ?? tuesday, today: today ?? tuesday
        )
    }

    @Test func addingAPhotoStoresItsFileAndItsRecord() throws {
        let (library, store, files) = try openLibrary()
        let photo = try add(library)

        #expect(try store.photos(on: tuesday).map(\.fileName) == [photo.fileName])
        #expect(try files.fileNames() == [photo.fileName])
    }

    @Test func cameraComesFromTheLensModelWhenItNamesOne() throws {
        let (library, _, _) = try openLibrary()
        let photo = try add(library, preset: .front, lensModel: "iPhone 15 Pro back triple camera 6.765mm f/1.78")

        #expect(photo.camera == .back, "the user can flip the camera in the system sheet, so the metadata wins over the preset")
    }

    @Test func cameraFallsBackToThePresetWhenTheLensModelIsMissing() throws {
        let (library, _, _) = try openLibrary()

        #expect(try add(library, preset: .back, lensModel: nil).camera == .back)
    }

    @Test func photoKeepsTheZoneItWasTakenInEvenWhenItDiffersFromTheCurrentOne() throws {
        let (library, store, _) = try openLibrary()
        let metadata = CaptureMetadata(lensModel: nil, dateTimeOriginal: "2026:10:08 23:30:00", offsetTimeOriginal: "-07:00")
        let moment = try #require(metadata.shutterMoment(fallbackZone: TimeZone(identifier: "Asia/Tokyo")!))
        let shotDay = LocalDate(year: 2026, month: 10, day: 8)

        _ = try library.add(
            imageData: imageData(), slot: "face", kind: .photo, presetCamera: .front, lensModel: nil,
            takenAt: moment.instant, in: moment.timeZone, filedOn: shotDay, today: shotDay
        )

        let stored = try #require(try store.photos(on: shotDay).first)
        let zone = try #require(TimeZone(identifier: stored.timeZoneIdentifier))
        #expect(zone.secondsFromGMT(for: stored.takenAt) == -7 * 3600, "the viewer formats the time in the zone it was taken in")
        #expect(Day(loggedAt: stored.takenAt, in: zone).date == shotDay)
    }

    @Test func refusedFilingStoresNoFile() throws {
        let (library, store, files) = try openLibrary()

        #expect(throws: PhotoError.cannotFile(on: tuesday)) {
            try add(library, filedOn: tuesday, today: tuesday.adding(days: 3))
        }
        #expect(try files.fileNames().isEmpty, "a photo with no record would be an orphan")
        #expect(try store.days().isEmpty)
    }

    @Test func unreadableImageStoresNoRecord() throws {
        let (library, store, _) = try openLibrary()

        #expect(throws: PhotoFileError.unreadableImage) {
            try library.add(
                imageData: Data("nope".utf8), slot: "face", kind: .photo, presetCamera: .front, lensModel: nil,
                takenAt: taken, in: zone, filedOn: tuesday, today: tuesday
            )
        }
        #expect(try store.days().isEmpty)
    }

    @Test func deletingAPhotoRemovesRecordAndFile() throws {
        let (library, store, files) = try openLibrary()
        let photo = try add(library)

        try library.delete(photo)

        #expect(try store.photos(on: tuesday).isEmpty)
        #expect(try files.fileNames().isEmpty)
    }

    @Test func orphanFilesAreReportedAndNeverDeleted() throws {
        let (library, _, files) = try openLibrary()
        let kept = try add(library)
        let orphan = try files.save(imageData: imageData())

        #expect(try library.orphanFileNames() == [orphan])
        #expect(try files.fileNames() == [kept.fileName, orphan], "a file with no record may be the only copy of a photo")
    }

    @Test func photosSurviveAStoreThatHasNoRecordOfThem() throws {
        let (library, _, files) = try openLibrary()
        let first = try add(library)
        let second = try add(library, slot: "left-hand")
        let resetStore = try DayStore(at: directory.appendingPathComponent("reset-store.sqlite"))
        let afterReset = PhotoLibrary(store: resetStore, files: files)

        #expect(Set(try afterReset.orphanFileNames()) == [first.fileName, second.fileName])
        #expect(try files.fileNames() == [first.fileName, second.fileName], "opening a store with no records deletes nothing")
    }

    @Test func deletingADayRemovesItsRecordsAndFilesAndKeepsOtherDays() throws {
        let (library, store, files) = try openLibrary()
        let doomed = try add(library, filedOn: tuesday, today: tuesday)
        let kept = try add(library, filedOn: tuesday.adding(days: 1), today: tuesday.adding(days: 1))

        try library.deleteDay(tuesday)

        #expect(try store.photos(on: tuesday).isEmpty)
        #expect(try files.fileNames() == [kept.fileName])
        #expect(!(try files.fileNames()).contains(doomed.fileName))
    }

    @Test func deletingAllDaysRemovesEveryRecordAndFile() throws {
        let (library, store, files) = try openLibrary()
        _ = try add(library, filedOn: tuesday, today: tuesday)
        _ = try add(library, filedOn: tuesday.adding(days: 1), today: tuesday.adding(days: 1))

        try library.deleteAllDays()

        #expect(try store.days().isEmpty)
        #expect(try files.fileNames().isEmpty)
    }
}
