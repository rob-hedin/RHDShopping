import CoreLocation
import Foundation

/// `CLLocationManager`, asked for a single reading at a time and only while
/// the app is in use (the app never tracks in the background).
@MainActor
final class SystemLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationWaiters: [CheckedContinuation<LocationAuthorization, Never>] = []
    private var locationWaiters: [CheckedContinuation<GeoPoint, Error>] = []

    override init() {
        super.init()
        manager.delegate = self
        // A store is a building; kilometer accuracy is plenty to find the
        // nearest one, and "in the store" only needs about a hundred meters.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var authorization: LocationAuthorization { Self.map(manager.authorizationStatus) }

    func requestAuthorization() async -> LocationAuthorization {
        guard manager.authorizationStatus == .notDetermined else { return authorization }
        return await withCheckedContinuation { continuation in
            authorizationWaiters.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentLocation() async throws -> GeoPoint {
        try await withCheckedThrowingContinuation { continuation in
            locationWaiters.append(continuation)
            manager.requestLocation()
        }
    }

    private static func map(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted, .denied: .denied
        default: .authorized
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard manager.authorizationStatus != .notDetermined else { return }
            let result = Self.map(manager.authorizationStatus)
            let waiters = authorizationWaiters
            authorizationWaiters = []
            waiters.forEach { $0.resume(returning: result) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let point = GeoPoint(location.coordinate)
        Task { @MainActor in
            let waiters = locationWaiters
            locationWaiters = []
            waiters.forEach { $0.resume(returning: point) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let waiters = locationWaiters
            locationWaiters = []
            waiters.forEach { $0.resume(throwing: error) }
        }
    }
}
