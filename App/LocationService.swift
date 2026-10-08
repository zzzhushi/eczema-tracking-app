import CoreLocation
import ExzemaCore
import Observation

/// Asks for location permission while the app is in use and supplies one current location at a time.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate, LocationSource {
    private(set) var status: CLAuthorizationStatus
    var onAuthorized: (() -> Void)?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var pending: CheckedContinuation<Coordinate?, Never>?

    var isAuthorized: Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    override init() {
        status = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestPermission() {
        guard status == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func currentLocation() async -> Coordinate? {
        guard isAuthorized, pending == nil else { return nil }
        return await withCheckedContinuation { continuation in
            pending = continuation
            manager.requestLocation()
        }
    }

    private func finish(_ coordinate: Coordinate?) {
        pending?.resume(returning: coordinate)
        pending = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.map {
            Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        Task { @MainActor in finish(coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in finish(nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            status = newStatus
            if isAuthorized { onAuthorized?() }
        }
    }
}
