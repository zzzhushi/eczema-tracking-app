import CoreLocation
import ExzemaCore
import MapKit

/// Looks up the city for a rounded position with Apple's maps service, which receives that position.
struct CityNamer: PlaceNaming {
    func placeName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        do {
            let items = try await request.mapItems
            return items.first?.addressRepresentations?.cityName
        } catch {
            return nil
        }
    }
}
