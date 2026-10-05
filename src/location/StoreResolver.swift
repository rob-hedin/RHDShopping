import Foundation

/// Picks the store a person is nearest to, and decides whether they're in it.
enum StoreResolver {
    /// How close counts as "in the store". Kroger's coordinates are for the
    /// building and phone GPS drifts indoors and in car parks, so this is
    /// generous without reaching the shop next door.
    static let inStoreRadiusMeters: Double = 150

    struct Match: Equatable {
        let store: StoreCandidate
        let distanceMeters: Double
        let isInStore: Bool
    }

    /// The closest candidate that has a location, or nil if none do.
    static func nearest(
        in candidates: [StoreCandidate],
        to user: GeoPoint,
        inStoreRadius: Double = inStoreRadiusMeters
    ) -> Match? {
        candidates
            .compactMap { candidate in candidate.point.map { (candidate, user.distance(to: $0)) } }
            .min { $0.1 < $1.1 }
            .map { Match(store: $0.0, distanceMeters: $0.1, isInStore: $0.1 <= inStoreRadius) }
    }
}
