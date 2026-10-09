import ExzemaCore
import Foundation
import Observation
import UIKit

/// Opens the store, catalog, and diagnostics at launch and hands the food section what it needs.
@MainActor
@Observable
final class AppModel {
    private(set) var failure: String?
    private(set) var catalogFailure: String?
    let foodServices: FoodServices
    let session: DaySession
    let location = LocationService()
    /// Dates that have a day row, kept current by observing the store.
    private(set) var savedDates: Set<LocalDate> = []
    private(set) var areas: [Area] = []
    private(set) var checkIns: [String: CheckIn] = [:]
    private(set) var places = DayPlaces(names: [], captureCount: 0)
    private(set) var photoSlots: [PhotoSlot] = []
    /// The shown day's photos, by slot and capture time.
    private(set) var photos: [StoredPhoto] = []
    private(set) var photoFailure: String?
    /// Photos captured and not yet stored; each one exists only in memory until its save finishes.
    private(set) var savingPhotos = 0
    let photoFlow = PhotoFlow()
    private var checkInsFailed = false
    private var placesFailed = false
    private var photosFailed = false

    /// Set while the shown day's ratings, places, or photos could not be read; they then show as unknown, never as
    /// another day's values.
    var loadFailure: String? {
        checkInsFailed || placesFailed || photosFailed ? "Part of this day could not be loaded." : nil
    }

    /// Whether the shown day takes a new photo: only today and yesterday do, and only while photos can be stored.
    var canAddPhotos: Bool {
        photoLibrary != nil && PhotoFiling.canFile(on: session.host.shownDate, today: session.host.today.date)
    }
    /// Changes when debug actions clear data, so the food section reloads.
    private(set) var dataVersion = 0

    private let store: DayStore?
    private let locationRecorder: LocationRecorder?
    private let photoFiles: PhotoFileStore?
    private let photoLibrary: PhotoLibrary?
    @ObservationIgnored private let thumbnails = NSCache<NSString, UIImage>()
    private var isCapturingLocation = false
    private let diagnostics = DiagnosticsListener()
    /// Kept so the session keeps hearing the system's clock notifications for the app's lifetime.
    private let dayEvents: DayEventObserver
    /// What the app takes as now: the real clock, or the debug clock that moves it in debug builds.
    private let clock: @Sendable () -> Date
    #if DEBUG
    private let debugClock: DebugClock
    #endif

    init() {
        do {
            let directory = try AppPaths.applicationSupport().appendingPathComponent("Logs", isDirectory: true)
            try LogFiles.enable(directory: directory)
        } catch {
            // Only the unified log is active at this point, so this is the one place the failure is recorded.
            Log.app.error("fileLog.unavailable", private: ["error": String(describing: error)])
        }
        Log.app.notice("app.launched", public: ["build": .int(BuildInfo(stamp: BuildStamp.value).number ?? 0)])
        let openedStore: DayStore?
        do {
            let directory = try AppPaths.applicationSupport().appendingPathComponent("Store", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            openedStore = try DayStore(at: directory.appendingPathComponent("store.sqlite"))
        } catch {
            openedStore = nil
            failure = "The store could not be opened."
            Log.storage.fault("store.unavailable", private: ["error": String(describing: error)])
        }
        let matching = Self.loadCatalog()
        if matching == nil { catalogFailure = "The food catalog could not be loaded." }
        store = openedStore
        var openedFiles: PhotoFileStore?
        if openedStore != nil {
            do {
                let directory = try AppPaths.applicationSupport().appendingPathComponent("Photos", isDirectory: true)
                openedFiles = try PhotoFileStore(directory: directory)
            } catch {
                failure = "The photo folder could not be opened."
                Log.photos.fault("photos.unavailable", private: ["error": String(describing: error)])
            }
        }
        photoFiles = openedFiles
        photoLibrary = openedStore.flatMap { store in openedFiles.map { PhotoLibrary(store: store, files: $0) } }
        #if DEBUG
        let debugClock = DebugClock()
        self.debugClock = debugClock
        let clock: @Sendable () -> Date = { debugClock.now }
        let session = DaySession(clock: clock)
        #else
        let clock: @Sendable () -> Date = { Date() }
        let session = DaySession()
        #endif
        self.session = session
        self.clock = clock
        let source = location
        locationRecorder = openedStore.map { LocationRecorder(store: $0, source: source, now: clock, places: CityNamer()) }
        foodServices = FoodServices(store: openedStore, matching: matching, session: session)
        dayEvents = DayEventObserver(
            session: session,
            clockNotifications: DayEventObserver.foundationClockNotifications + [UIApplication.significantTimeChangeNotification]
        )
        location.onAuthorized = { [weak self] in self?.captureLocationIfDue() }
        do {
            try photoLibrary?.removeOrphanFiles()
        } catch {
            Log.photos.error("photos.cleanupFailed", private: ["error": String(describing: error)])
        }
        #if DEBUG
        photoFlow.simulatorCapture = { [weak self] request in self?.addDebugPhoto(for: request) }
        #endif
        loadAreas()
        loadPhotoSlots()
        observeSavedDates()
    }

    /// Record the rounded location unless one was taken within the last hour; does nothing without permission.
    ///
    /// Overlapping calls are dropped so two triggers at launch cannot each store a capture.
    func captureLocationIfDue() {
        guard location.isAuthorized, let locationRecorder, !isCapturingLocation else { return }
        isCapturingLocation = true
        Task {
            await locationRecorder.captureIfDue()
            await locationRecorder.fillMissingPlaceNames()
            isCapturingLocation = false
            loadPlaces()
        }
    }

    /// Load the shown day's check-ins; call when the shown date or the stored data changes.
    func loadCheckIns() {
        checkIns = [:]
        checkInsFailed = false
        guard let store else { return }
        do {
            let rows = try store.checkIns(on: session.host.shownDate)
            checkIns = Dictionary(uniqueKeysWithValues: rows.map { ($0.areaID, $0) })
        } catch {
            checkInsFailed = true
            Log.storage.error("store.readFailed", public: ["query": "checkIns"], private: ["error": String(describing: error)])
        }
    }

    /// Load the places captured on the shown date.
    func loadPlaces() {
        places = DayPlaces(names: [], captureCount: 0)
        placesFailed = false
        guard let store else { return }
        do {
            places = try store.places(on: session.host.shownDate)
        } catch {
            placesFailed = true
            Log.storage.error("store.readFailed", public: ["query": "places"], private: ["error": String(describing: error)])
        }
    }

    /// Load the photos filed under the shown date.
    func loadPhotos() {
        photos = []
        photosFailed = false
        guard let store else { return }
        do {
            photos = try store.photos(on: session.host.shownDate)
        } catch {
            photosFailed = true
            Log.storage.error("store.readFailed", public: ["query": "photos"], private: ["error": String(describing: error)])
        }
    }

    func photos(in slot: PhotoSlot, kind: PhotoKind) -> [StoredPhoto] {
        photos.filter { $0.slotID == slot.id && $0.kind == kind }
    }

    /// File a captured image under the shown day.
    ///
    /// The capture time, time zone, and days are fixed here on the main actor; encoding, resizing, and writing the
    /// file and record run in the background, and the day's photos reload when they finish.
    func addPhoto(_ capture: CapturedPhoto, metadata: CaptureMetadata, request: CaptureRequest) {
        guard let photoLibrary else {
            photoFailure = "Photos can't be stored right now."
            return
        }
        photoFailure = nil
        let timeZone = TimeZone.autoupdatingCurrent
        let takenAt = metadata.shutterTime(fallbackZone: timeZone) ?? clock()
        let lensModel = metadata.lensModel
        let filedOn = session.host.shownDate
        let today = session.host.today.date
        let background = BackgroundWork(name: "photo.save")
        savingPhotos += 1
        Task { [weak self] in
            let outcome = await Task.detached { () -> Result<Void, any Error> in
                Result {
                    guard let data = capture.image.jpegData(compressionQuality: 0.95) else { throw PhotoFileError.unreadableImage }
                    try photoLibrary.add(
                        imageData: data, slot: request.slot.id, kind: request.kind, presetCamera: request.slot.presetCamera,
                        lensModel: lensModel, takenAt: takenAt, in: timeZone, filedOn: filedOn, today: today
                    )
                }
            }.value
            background.end()
            guard let self else { return }
            savingPhotos -= 1
            if case .failure(let error) = outcome {
                photoFailure = "The photo could not be saved."
                Log.photos.error("photo.saveFailed", private: ["error": String(describing: error)])
            }
            loadPhotos()
        }
    }

    func deletePhoto(_ photo: StoredPhoto) {
        guard let photoLibrary else { return }
        do {
            try photoLibrary.delete(photo)
        } catch {
            photoFailure = "The photo could not be deleted."
            Log.photos.error("photo.deleteFailed", private: ["error": String(describing: error)])
        }
        thumbnails.removeObject(forKey: photo.fileName as NSString)
        loadPhotos()
    }

    /// A small version of a stored photo for the day screen.
    func thumbnail(for photo: StoredPhoto) async -> UIImage? {
        if let cached = thumbnails.object(forKey: photo.fileName as NSString) { return cached }
        guard let photoFiles else { return nil }
        let name = photo.fileName
        let data = await Task.detached { try? photoFiles.thumbnailData(fileName: name, maxPixel: 240) }.value
        guard let data, let image = UIImage(data: data) else { return nil }
        thumbnails.setObject(image, forKey: name as NSString)
        return image
    }

    /// A stored photo at its full stored size.
    func image(for photo: StoredPhoto) async -> UIImage? {
        guard let photoFiles else { return nil }
        let name = photo.fileName
        let data = await Task.detached { try? photoFiles.imageData(fileName: name) }.value
        return data.flatMap { UIImage(data: $0) }
    }

    /// Give the shown day's area a rating, or clear it with nil.
    func setRating(_ kind: RatingKind, to value: Int?, area: Area) {
        guard let store else { return }
        do {
            try store.setRating(kind, to: value, area: area.id, on: session.host.day, at: clock())
        } catch {
            Log.checkIn.error("checkin.saveFailed", private: ["error": String(describing: error)])
        }
        loadCheckIns()
    }

    private func loadPhotoSlots() {
        guard let store else { return }
        do {
            photoSlots = try store.photoSlots()
        } catch {
            Log.storage.error("store.readFailed", public: ["query": "photoSlots"], private: ["error": String(describing: error)])
        }
    }

    private func loadAreas() {
        guard let store else { return }
        do {
            areas = try store.activeAreas()
        } catch {
            Log.storage.error("store.readFailed", public: ["query": "areas"], private: ["error": String(describing: error)])
        }
    }

    private func observeSavedDates() {
        guard let store else { return }
        Task { [weak self] in
            do {
                for try await dates in store.savedDates() { self?.savedDates = dates }
            } catch {
                Log.storage.error("store.observeFailed", private: ["error": String(describing: error)])
            }
        }
    }

    /// Nil when the bundled catalog cannot be loaded; nothing parses food without it.
    private static func loadCatalog() -> FoodMatching? {
        do {
            guard let directory = Bundle.main.resourceURL else { throw CocoaError(.fileNoSuchFile) }
            let matching = try FoodMatching.load(dataDirectory: directory)
            Log.foodLogging.notice("catalog.loaded", public: [
                "catalogVersion": .int(matching.catalog.manifest.catalogVersion),
                "foods": .int(matching.catalog.foods.count),
            ])
            return matching
        } catch {
            Log.foodLogging.fault("catalog.unavailable", private: ["error": String(describing: error)])
            return nil
        }
    }

    #if DEBUG
    func clearToday() {
        guard let store else { return }
        try? store.delete(session.host.today.date)
        try? photoLibrary?.removeOrphanFiles()
        dataVersion += 1
        loadCheckIns()
        loadPhotos()
    }

    /// Adds a plain generated image to the requested slot, for walking the photo screens in the simulator.
    func addDebugPhoto(for request: CaptureRequest) {
        let size = CGSize(width: 1200, height: 900)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(hue: .random(in: 0...1), saturation: 0.35, brightness: 0.9, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            context.fill(CGRect(x: 300, y: 250, width: 600, height: 400))
        }
        addPhoto(
            CapturedPhoto(image: image),
            metadata: CaptureMetadata(lensModel: nil, dateTimeOriginal: nil, offsetTimeOriginal: nil),
            request: request
        )
    }

    /// Moves the app's clock to just after the next midnight and refreshes, as the system's day-changed
    /// notification does.
    func simulateMidnight() {
        debugClock.offset = nextMidnight().addingTimeInterval(60).timeIntervalSinceNow
        session.handle(.clockChanged)
    }

    /// Leaves the foreground, moves the clock to 8 a.m. the next day, and returns, as opening the app the
    /// next morning does.
    func simulateNextMorning() {
        session.handle(.enteredBackground)
        debugClock.offset = nextMidnight().addingTimeInterval(8 * 3600).timeIntervalSinceNow
        session.handle(.becameActive)
        captureLocationIfDue()
    }

    func resetClock() {
        debugClock.offset = 0
        session.handle(.clockChanged)
    }

    private func nextMidnight() -> Date {
        Calendar.autoupdatingCurrent.nextDate(
            after: debugClock.now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime
        )!
    }

    func clearAll() {
        guard let store else { return }
        try? store.deleteAll()
        try? photoLibrary?.removeOrphanFiles()
        dataVersion += 1
        loadCheckIns()
        loadPhotos()
    }
    #endif
}

#if DEBUG
/// Shifts what the app takes as now, so day boundaries can be walked through without waiting for midnight.
final class DebugClock: @unchecked Sendable {
    var offset: TimeInterval = 0
    var now: Date { Date().addingTimeInterval(offset) }
}
#endif
