import Foundation
import RHKrogerAPI

/// The slice of `KrogerProducts` the product detail screen depends on, so
/// Previews and tests can stand in for it (same reasoning as `ProductSearching`).
protocol ProductFetching: Sendable {
    func product(id: String, locationID: String?) async throws -> KrogerProduct
}

extension KrogerProducts: ProductFetching {}
