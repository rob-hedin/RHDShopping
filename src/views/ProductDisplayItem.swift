import Foundation
import RHKrogerAPI

/// A trimmed-down, display-ready view of a `KrogerProduct`.
///
/// `KrogerProduct` (and the types it's built from) have no public
/// initializer — RHKrogerAPI only ever hands you one back from a network
/// call, you can't construct one yourself. That's fine for production code,
/// but it means the UI layer can't build sample data for Previews or tests
/// if it works directly with `KrogerProduct`. `ProductDisplayItem` is the
/// seam: it holds only what the product picker screen shows a person, it's
/// a plain struct we can construct anywhere, and `KrogerProduct.asDisplayItem()`
/// below is the one place that maps real API data onto it.
struct ProductDisplayItem: Identifiable, Hashable {
    let id: String
    let brand: String?
    let description: String
    let category: String?
    let imageURL: URL?

    /// The shelf price. Still present even when a promo is active, so it
    /// can be shown struck through alongside it.
    let regularPrice: Decimal?
    /// Only set when a promo is actually in effect (see `KrogerProduct.activePromo`).
    let promoPrice: Decimal?
    /// Per-unit estimate for whichever price is in effect: the promo's own
    /// estimate while a promo is active, otherwise the regular one.
    let pricePerUnit: Decimal?

    var isOnPromo: Bool { promoPrice != nil }

    /// Whichever price actually applies right now: the promo when one's
    /// running, otherwise the regular price. What a running total should add up.
    var effectivePrice: Decimal? { promoPrice ?? regularPrice }

    var regularPriceText: String? { regularPrice?.formatted(.currency(code: "USD")) }
    var promoPriceText: String? { promoPrice?.formatted(.currency(code: "USD")) }
    var pricePerUnitText: String? {
        guard let pricePerUnit else { return nil }
        return "\(pricePerUnit.formatted(.currency(code: "USD"))) per unit"
    }
}

extension KrogerProduct {
    /// Maps this product onto what the product picker screen displays.
    ///
    /// Pricing comes from the product's first item. A product with several
    /// sizes/variants (multiple `items`) will need a size picker of its own
    /// before this screen can show more than the first one — out of scope
    /// for this list screen.
    func asDisplayItem() -> ProductDisplayItem {
        let item = items.first
        // Store price when we have one, otherwise national price — but
        // never mix fields from the two, since a promo and its per-unit
        // estimate only make sense read together, from the same source.
        let price = item?.price ?? item?.nationalPrice
        let promo = Self.activePromo(price)

        return ProductDisplayItem(
            id: id,
            brand: brand,
            description: description ?? receiptDescription ?? "Unnamed product",
            category: categories.first?.capitalized,
            imageURL: preferredImageURL,
            regularPrice: price?.regular,
            promoPrice: promo,
            pricePerUnit: promo != nil ? price?.promoPerUnitEstimate : price?.regularPerUnitEstimate
        )
    }

    /// The service reports `promo` as `0`, not absent, when no discount is
    /// running — so "there's a promo" means a positive promo price that
    /// actually undercuts the regular one, not merely a non-nil value.
    private static func activePromo(_ price: KrogerItemPrice?) -> Decimal? {
        guard let promo = price?.promo, promo > 0 else { return nil }
        if let regular = price?.regular, promo >= regular { return nil }
        return promo
    }

    /// The best available thumbnail: the default image (falling back to the
    /// first one), preferring a size suited to a small list row.
    private var preferredImageURL: URL? {
        let rowSizePreference = ["medium", "thumbnail", "small", "large", "xlarge"]
        guard let image = images.first(where: \.isDefault) ?? images.first else { return nil }
        for size in rowSizePreference {
            if let match = image.sizes.first(where: { $0.size?.lowercased() == size })?.url {
                return match
            }
        }
        return image.sizes.first(where: { $0.url != nil })?.url
    }
}
