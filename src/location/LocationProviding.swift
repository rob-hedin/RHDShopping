import CoreLocation
import Foundation

/// Whether the app may use the device's location.
enum LocationAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

/// The device's location, behind a protocol so the store logic can be
/// tested with a fake.
@MainActor
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    /// Shows the system prompt if it hasn't been shown, and returns the answer.
    func requestAuthorization() async -> LocationAuthorization
    /// One fresh fix. Throws if there isn't one.
    func currentLocation() async throws -> GeoPoint
}
