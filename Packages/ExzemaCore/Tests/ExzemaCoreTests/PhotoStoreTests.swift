import Foundation
import Testing
import ExzemaCore

@Suite("Photo store")
struct PhotoStoreTests {
    private let directory: URL
    private let zone = TimeZone(identifier: "America/Los_Angeles")!
    private let tuesday = LocalDate(year: 2026, month: 10, day: 6)
    private let wednesday = LocalDate(year: 2026, month: 10, day: 7)
    private let tuesdayEvening = Date(timeIntervalSince1970: 1_791_000_000)

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func openStore() throws -> DayStore {
        try DayStore(at: directory.appendingPathComponent("store.sqlite"))
    }

    private func add(
        _ store: DayStore,
        file: String,
        slot: String = "face",
        kind: PhotoKind = .photo,
        takenAt: Date? = nil,
        filedOn: LocalDate? = nil,
        today: LocalDate? = nil
    ) throws -> StoredPhoto {
        try store.addPhoto(
            fileName: file, slot: slot, kind: kind, camera: .front,
            takenAt: takenAt ?? tuesdayEvening, in: zone,
            filedOn: filedOn ?? tuesday, today: today ?? tuesday
        )
    }

    @Test func newStoreOffersFaceThenLeftThenRightHand() throws {
        let slots = try openStore().photoSlots()

        #expect(slots.map(\.id) == ["face", "left-hand", "right-hand"])
        #expect(slots.map(\.areaID) == ["face", "hands", "hands"])
        #expect(slots.map(\.name) == ["Face", "Left hand", "Right hand"])
    }

    @Test func faceUsesTheFrontCameraAndOffersCloseUpsWhileHandsUseTheBackCameraWithoutThem() throws {
        let slots = Dictionary(uniqueKeysWithValues: try openStore().photoSlots().map { ($0.id, $0) })

        #expect(slots["face"]?.presetCamera == .front)
        #expect(slots["face"]?.offersCloseUp == true)
        #expect(slots["left-hand"]?.presetCamera == .back)
        #expect(slots["right-hand"]?.presetCamera == .back)
        #expect(slots["left-hand"]?.offersCloseUp == false)
        #expect(slots["right-hand"]?.offersCloseUp == false)
    }

    @Test func dayWithoutPhotosHasNone() throws {
        let store = try openStore()

        #expect(try store.photos(on: tuesday).isEmpty)
        #expect(try store.days().isEmpty, "reading a day never creates it")
    }

    @Test func firstPhotoCreatesTheDayInTheCaptureTimeZone() throws {
        let store = try openStore()
        _ = try add(store, file: "a.jpg")

        #expect(try store.days() == [Day(date: tuesday, timeZoneIdentifier: zone.identifier)])
    }

    @Test func severalPhotosInOneSlotAreAllKeptOldestFirst() throws {
        let store = try openStore()
        let later = tuesdayEvening.addingTimeInterval(60)
        _ = try add(store, file: "second.jpg", takenAt: later)
        _ = try add(store, file: "first.jpg", takenAt: tuesdayEvening)

        #expect(try store.photos(on: tuesday).map(\.fileName) == ["first.jpg", "second.jpg"])
    }

    @Test func photosAreOrderedBySlotThenCaptureTime() throws {
        let store = try openStore()
        _ = try add(store, file: "right.jpg", slot: "right-hand")
        _ = try add(store, file: "left.jpg", slot: "left-hand")
        _ = try add(store, file: "face.jpg", slot: "face")

        #expect(try store.photos(on: tuesday).map(\.fileName) == ["face.jpg", "left.jpg", "right.jpg"])
    }

    @Test func closeUpIsStoredAsItsOwnPhotoWithItsKind() throws {
        let store = try openStore()
        _ = try add(store, file: "wide.jpg", kind: .photo)
        _ = try add(store, file: "close.jpg", kind: .closeUp)

        let photos = try store.photos(on: tuesday)
        #expect(photos.map(\.kind).sorted { $0.rawValue < $1.rawValue } == [.closeUp, .photo])
        #expect(photos.first { $0.fileName == "close.jpg" }?.kind == .closeUp)
    }

    @Test(arguments: ["left-hand", "right-hand"])
    func closeUpOfASlotThatDoesNotOfferOneIsRefusedAndWritesNothing(slot: String) throws {
        let store = try openStore()

        #expect(throws: PhotoError.closeUpNotOffered(slot)) { try add(store, file: "hand.jpg", slot: slot, kind: .closeUp) }
        #expect(try store.days().isEmpty, "a refused photo writes no day")
        #expect(try store.allPhotoFileNames().isEmpty)
    }

    @Test func photoRecordsCameraTimeAndZone() throws {
        let store = try openStore()
        let stored = try store.addPhoto(
            fileName: "hand.jpg", slot: "left-hand", kind: .photo, camera: .back,
            takenAt: tuesdayEvening, in: zone, filedOn: tuesday, today: tuesday
        )

        #expect(stored.camera == .back)
        #expect(stored.slotID == "left-hand")
        #expect(stored.date == tuesday)
        #expect(stored.timeZoneIdentifier == zone.identifier)
        #expect(abs(stored.takenAt.timeIntervalSince(tuesdayEvening)) < 0.01)
    }

    @Test func photoTakenAfterMidnightCanBeFiledUnderYesterdayAndKeepsItsRealTime() throws {
        let store = try openStore()
        let afterMidnight = tuesdayEvening.addingTimeInterval(8 * 3_600)
        _ = try add(store, file: "late.jpg", takenAt: afterMidnight, filedOn: tuesday, today: wednesday)

        #expect(try store.photos(on: tuesday).map(\.fileName) == ["late.jpg"])
        #expect(try store.photos(on: wednesday).isEmpty)
        let stored = try #require(try store.photos(on: tuesday).first)
        #expect(abs(stored.takenAt.timeIntervalSince(afterMidnight)) < 0.01, "the real capture time is never rewritten")
    }

    @Test func photoCannotBeFiledEarlierThanYesterday() throws {
        let store = try openStore()

        #expect(throws: PhotoError.cannotFile(on: tuesday)) {
            try add(store, file: "old.jpg", filedOn: tuesday, today: tuesday.adding(days: 2))
        }
        #expect(try store.days().isEmpty, "a refused photo writes nothing")
    }

    @Test func photoCannotBeFiledOnAFutureDay() throws {
        let store = try openStore()

        #expect(throws: PhotoError.cannotFile(on: wednesday)) {
            try add(store, file: "future.jpg", filedOn: wednesday, today: tuesday)
        }
    }

    @Test func filingWindowIsTodayAndYesterday() {
        #expect(PhotoFiling.canFile(on: wednesday, today: wednesday))
        #expect(PhotoFiling.canFile(on: tuesday, today: wednesday))
        #expect(!PhotoFiling.canFile(on: tuesday, today: wednesday.adding(days: 1)))
        #expect(!PhotoFiling.canFile(on: wednesday, today: tuesday))
    }

    @Test func unknownSlotThrowsAndWritesNothing() throws {
        let store = try openStore()

        #expect(throws: PhotoError.unknownSlot("chin")) { try add(store, file: "x.jpg", slot: "chin") }
        #expect(try store.days().isEmpty)
    }

    @Test func fileNameCannotBeStoredTwice() throws {
        let store = try openStore()
        _ = try add(store, file: "same.jpg")

        #expect(throws: (any Error).self) { try add(store, file: "same.jpg") }
        #expect(try store.photos(on: tuesday).count == 1)
    }

    @Test func deletingAPhotoRemovesItsRowAndReturnsItsFileName() throws {
        let store = try openStore()
        let kept = try add(store, file: "keep.jpg")
        let removed = try add(store, file: "remove.jpg")

        let fileName = try store.deletePhoto(id: removed.id)

        #expect(fileName == "remove.jpg")
        #expect(try store.photos(on: tuesday).map(\.id) == [kept.id])
    }

    @Test func deletingAnUnknownPhotoChangesNothing() throws {
        let store = try openStore()
        _ = try add(store, file: "keep.jpg")

        #expect(try store.deletePhoto(id: 9_999) == nil)
        #expect(try store.photos(on: tuesday).count == 1)
    }

    @Test func deletingTheLastPhotoLeavesTheDay() throws {
        let store = try openStore()
        let photo = try add(store, file: "only.jpg")
        _ = try store.deletePhoto(id: photo.id)

        #expect(try store.days().count == 1, "a day is not removed when its content goes")
    }

    @Test func deletingADayRemovesItsPhotoRows() throws {
        let store = try openStore()
        _ = try add(store, file: "a.jpg")
        try store.delete(tuesday)

        #expect(try store.photos(on: tuesday).isEmpty)
    }

    @Test func everyStoredPhotoFileNameIsListed() throws {
        let store = try openStore()
        _ = try add(store, file: "a.jpg")
        _ = try add(store, file: "b.jpg", slot: "left-hand")

        #expect(try store.allPhotoFileNames().sorted() == ["a.jpg", "b.jpg"])
    }
}
