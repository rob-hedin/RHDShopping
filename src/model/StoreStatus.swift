import Foundation

/// A Kroger store, as much as the app needs to know about it.
struct StoreRef: Hashable, Codable {
    /// The eight-character location ID the Products API wants.
    let id: String
    let name: String
}

/// Where the app stands on knowing which store to use. Whatever works this
/// out (nearest-store lookup, in-store detection, a manual pick) reports it
/// as one of these, so the screens only ever react to a value.
enum StoreStatus: Equatable {
    /// Location hasn't been allowed yet.
    case needsPermission
    /// Working out the nearest store.
    case locating
    /// The nearest store, while the person is somewhere else (planning).
    case nearest(StoreRef)
    /// The person is in this store, so the list shows its prices and stock.
    case inStore(StoreRef)
    /// The person picked a store by hand (ZIP code search).
    case chosen(StoreRef)
    /// Location is off or nothing was found, and no store has been chosen.
    case unavailable

    /// The store to price against, when there is one.
    var store: StoreRef? {
        switch self {
        case .nearest(let store), .inStore(let store), .chosen(let store): store
        case .needsPermission, .locating, .unavailable: nil
        }
    }

    var isInStore: Bool {
        if case .inStore = self { true } else { false }
    }
}
