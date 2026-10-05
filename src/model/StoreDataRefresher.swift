import Foundation
import RHKrogerAPI

/// What a refresh found for a store.
struct StoreRefreshResult: Equatable {
    /// Current price, aisle and stock for each product the store returned,
    /// keyed by product ID.
    var fresh: [String: ShoppingListItemDisplay]
    /// Products the store didn't return, meaning it doesn't carry them.
    var missingIDs: [String]
}

/// Looks up current price, aisle and stock for a set of products at one store.
///
/// The fetching is a closure so tests can supply their own; `kroger(_:)` is
/// the real one, which asks the Products API for up to 50 products per call.
struct StoreDataRefresher: Sendable {
    typealias Fetch = @Sendable (_ productIDs: [String], _ storeID: String) async throws -> [ShoppingListItemDisplay]

    /// The Products API takes at most this many product IDs per request.
    static let batchSize = 50
    /// Product IDs are exactly this long; anything else can't be looked up.
    static let productIDLength = 13

    let fetch: Fetch

    init(fetch: @escaping Fetch) {
        self.fetch = fetch
    }

    /// The real refresher, backed by the Products API.
    static func kroger(_ products: KrogerProducts) -> StoreDataRefresher {
        StoreDataRefresher { ids, storeID in
            try await products
                .search(locationID: storeID, productIDs: ids)
                .map { $0.asShoppingListItem() }
        }
    }

    /// Fetches the products in batches. IDs that can't be looked up (the wrong
    /// length) are left out of the request and out of `missingIDs`, so a
    /// malformed one never blocks the rest.
    func refresh(productIDs: [String], storeID: String) async throws -> StoreRefreshResult {
        let lookupIDs = productIDs.filter { $0.count == Self.productIDLength }
        var fresh: [String: ShoppingListItemDisplay] = [:]
        for start in stride(from: 0, to: lookupIDs.count, by: Self.batchSize) {
            try Task.checkCancellation()
            let batch = Array(lookupIDs[start..<min(start + Self.batchSize, lookupIDs.count)])
            for item in try await fetch(batch, storeID) { fresh[item.id] = item }
        }
        return StoreRefreshResult(fresh: fresh, missingIDs: lookupIDs.filter { fresh[$0] == nil })
    }
}

extension ShoppingListItemDisplay {
    /// This entry updated with current store data: new price, aisle and stock,
    /// the person's quantities untouched.
    ///
    /// Anything already picked keeps its price. What was paid shouldn't change
    /// because the store did; only its aisle and stock are updated.
    func refreshed(from fresh: ShoppingListItemDisplay) -> ShoppingListItemDisplay {
        ShoppingListItemDisplay(
            id: id,
            product: quantityPicked > 0 ? product : fresh.product,
            aisle: fresh.aisle,
            quantityRequested: quantityRequested,
            quantityPicked: quantityPicked,
            stock: fresh.stock
        )
    }
}
