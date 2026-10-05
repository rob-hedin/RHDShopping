import Foundation
import RHKrogerAPI

/// The slice of `KrogerLocations` the store code depends on, so tests and
/// Previews can stand in without the network (same idea as `ProductSearching`).
protocol StoreSearching: Sendable {
    func stores(near point: GeoPoint) async throws -> [StoreCandidate]
    func stores(zipCode: String) async throws -> [StoreCandidate]
}

/// The real thing, backed by the Location API.
struct KrogerStoreSearch: StoreSearching {
    let locations: KrogerLocations
    var radiusInMiles = 10
    var limit = 10

    func stores(near point: GeoPoint) async throws -> [StoreCandidate] {
        try await locations
            .search(near: .coordinate(point.coordinate), radiusInMiles: radiusInMiles, limit: limit)
            .map { $0.asCandidate() }
    }

    func stores(zipCode: String) async throws -> [StoreCandidate] {
        try await locations
            .search(near: .zipCode(zipCode), radiusInMiles: radiusInMiles, limit: limit)
            .map { $0.asCandidate() }
    }
}
