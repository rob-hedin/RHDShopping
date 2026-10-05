import CoreLocation
import Foundation
import RHKrogerAPI

/// A point on the earth. A plain Hashable value, because
/// `CLLocationCoordinate2D` isn't Hashable.
struct GeoPoint: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Straight-line distance in meters.
    func distance(to other: GeoPoint) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

/// A store the app could use, trimmed to what choosing and detecting one
/// needs. `KrogerLocation` can't be built outside the framework, so the
/// location code works with this and `KrogerLocation.asCandidate()` is the
/// one place real API data is mapped onto it.
struct StoreCandidate: Hashable, Sendable {
    let ref: StoreRef
    /// One line, like "123 Main St, Cincinnati, OH".
    let addressLine: String?
    let point: GeoPoint?
    let hours: StoreHours?
}

extension KrogerLocation {
    func asCandidate() -> StoreCandidate {
        let address = self.address
        let street = address?.addressLine1
        let place = [address?.city, address?.state].compactMap { $0 }.joined(separator: ", ")
        let line = [street, place.isEmpty ? nil : place].compactMap { $0 }.joined(separator: ", ")
        return StoreCandidate(
            ref: StoreRef(id: id, name: name ?? chain ?? "Store"),
            addressLine: line.isEmpty ? nil : line,
            point: coordinate.map(GeoPoint.init),
            hours: hours.map(StoreHours.init)
        )
    }
}
