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

/// The two sections of the shopping list screen.
enum ShoppingListSection: Hashable {
    case needed, picked

    var title: String {
        switch self {
        case .needed: "Needed"
        case .picked: "Picked"
        }
    }
}

/// One product on the shopping list screen: the product (reusing the same
/// display/pricing rules as the picker), where it is in the store, and how
/// many the person wants versus how many they've picked up.
///
/// A product can sit in both sections at once: pick 1 of 2 and it shows in
/// Picked with a quantity of 1 and in Needed with the 1 still remaining.
/// Picking more than was requested is allowed; `quantityPicked` keeps the
/// real count so the Picked total reflects what's actually in the cart.
struct ShoppingListItemDisplay: Identifiable, Hashable {
    let id: String
    let product: ProductDisplayItem
    let aisle: AisleLocationDisplay?
    /// How many the person asked for when adding the product.
    var quantityRequested: Int = 1
    var quantityPicked: Int = 0
    /// Nil when the service reported nothing useful. Treated as unreliable:
    /// it only ever annotates a row, it never blocks picking it.
    var stock: ProductDetailDisplay.Stock?

    /// How many are still needed; zero once the request is met or exceeded.
    var quantityRemaining: Int { max(quantityRequested - quantityPicked, 0) }

    var isOutOfStock: Bool { stock == .outOfStock }

    /// What this section should show for this item, or nil if the item
    /// doesn't belong in it.
    func quantity(in section: ShoppingListSection) -> Int? {
        let quantity = section == .needed ? quantityRemaining : quantityPicked
        return quantity > 0 ? quantity : nil
    }

    /// Price of this section's quantity at the price in effect now.
    /// Items with no known price contribute nothing.
    func total(in section: ShoppingListSection) -> Decimal {
        Decimal(quantity(in: section) ?? 0) * (product.effectivePrice ?? 0)
    }
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
    func asShoppingListItem(quantityRequested: Int = 1, quantityPicked: Int = 0) -> ShoppingListItemDisplay {
        ShoppingListItemDisplay(
            id: id,
            product: asDisplayItem(),
            aisle: primaryAisleLocation,
            quantityRequested: quantityRequested,
            quantityPicked: quantityPicked,
            stock: items.first?.stockLevel.flatMap(Self.stock)
        )
    }
}
