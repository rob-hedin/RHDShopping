import Foundation
import RHKrogerAPI

/// Where to find a product on the shelf, trimmed to what a shopper needs:
/// the aisle's own description, which side it's on, and the shelf number.
struct AisleLocationDisplay: Hashable {
    let description: String?
    let side: String?
    let shelfNumber: String?

    /// A single human-readable line built from whichever parts the service
    /// actually reported (any of the three can be missing).
    var summaryText: String? {
        let parts = [
            description,
            side.map { "\($0) side" },
            shelfNumber.map { "Shelf \($0)" }
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{B7} ")
    }
}

/// One row on the shopping list screen: a product (reusing the same
/// display/pricing rules as the picker) plus where it is in the store and
/// whether it's been picked up yet.
struct ShoppingListItemDisplay: Identifiable, Hashable {
    let id: String
    let product: ProductDisplayItem
    let aisle: AisleLocationDisplay?
    var isPickedUp: Bool
}

extension KrogerProduct {
    /// The product's primary shelf location, when the service reports one.
    /// A product can list more than one `aisleLocations` entry; this screen
    /// only needs the first.
    var primaryAisleLocation: AisleLocationDisplay? {
        guard let aisle = aisleLocations.first else { return nil }
        return AisleLocationDisplay(description: aisle.description, side: aisle.side, shelfNumber: aisle.shelfNumber)
    }

    /// Composes a shopping-list row from this product, reusing `asDisplayItem()`
    /// for the brand/description/category/pricing so both screens stay in
    /// sync on how a product is shown and priced.
    func asShoppingListItem(isPickedUp: Bool) -> ShoppingListItemDisplay {
        ShoppingListItemDisplay(id: id, product: asDisplayItem(), aisle: primaryAisleLocation, isPickedUp: isPickedUp)
    }
}
