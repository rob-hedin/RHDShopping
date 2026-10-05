import Foundation
import RHKrogerAPI

/// The slice of `KrogerProducts` the product picker screen depends on.
///
/// The view model talks to this protocol instead of the concrete
/// `KrogerProducts` type so Previews and tests can supply a stand-in
/// without touching the network or holding a real `KrogerClient`.
/// `KrogerProducts.search` already has this exact signature, so it
/// satisfies the protocol with no extra code beyond the conformance below.
protocol ProductSearching {
    func search(
        term: String?,
        locationID: String?,
        productIDs: [String],
        brands: [String],
        fulfillment: Set<KrogerFulfillment>,
        start: Int?,
        limit: Int?
    ) async throws -> [KrogerProduct]
}

extension KrogerProducts: ProductSearching {}

extension ProductSearching {
    /// Convenience for the one call this screen makes: a term search at a
    /// known store, with no need for ID/brand/fulfillment filtering or paging.
    func search(term: String, locationID: String, limit: Int) async throws -> [KrogerProduct] {
        try await search(
            term: term,
            locationID: locationID,
            productIDs: [],
            brands: [],
            fulfillment: [],
            start: nil,
            limit: limit
        )
    }
}
