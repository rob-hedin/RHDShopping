import SwiftUI

/// One row on the shopping list: where to find it in the store, then
/// brand/description, then price — in that order — with the quantity on the
/// trailing edge. No category, no thumbnail; this list stays compact.
///
/// The row has no controls of its own: the whole row is tapped (the list
/// wraps it in a button) to open the pick dialog.
struct ShoppingListRowView: View {
    let item: ShoppingListItemDisplay
    let section: ShoppingListSection

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            details
            Spacer(minLength: 0)
            trailing
        }
        .padding(.vertical, 8)
        .opacity(section == .picked ? 0.5 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let location = item.aisle?.summaryText {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let brand = item.product.brand, !brand.isEmpty {
                Text(brand)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(item.product.description)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            priceRow

            if section == .needed, let tag = stockTag {
                Text(tag.text)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tag.foreground)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(tag.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(.top, 1)
            }
        }
    }

    /// Only the exceptions get a tag; in stock (or unknown) shows nothing.
    private var stockTag: (text: String, foreground: Color, background: Color)? {
        switch item.stock {
        case .lowStock: ("Low stock", .orange, .orange.opacity(0.15))
        case .outOfStock: ("Out of stock", .red, .red.opacity(0.15))
        case .inStock, nil: nil
        }
    }

    /// Same promo rules as the product picker row: promo price emphasized
    /// with the regular price struck through beside it, or just the regular
    /// price when there's no active promo.
    @ViewBuilder
    private var priceRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if item.product.isOnPromo, let promoText = item.product.promoPriceText {
                Text(promoText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                if let regularText = item.product.regularPriceText {
                    Text(regularText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .strikethrough()
                }
            } else if let regularText = item.product.regularPriceText {
                Text(regularText)
                    .font(.caption.weight(.bold))
            } else {
                Text("Price unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let perUnit = item.product.pricePerUnitText {
                Text(perUnit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trailing: some View {
        HStack(spacing: 10) {
            if section == .picked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Picked")
            }
            quantityBadge
        }
    }

    /// Needed shows what's still left ("1 of 2" once some are picked);
    /// Picked shows the actual count picked.
    private var quantityBadge: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("Qty").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text(quantityText).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Quantity \(quantityText)")
    }

    private var quantityText: String {
        let quantity = item.quantity(in: section) ?? 0
        if section == .needed, item.quantityPicked > 0 {
            return "\(quantity) of \(item.quantityRequested)"
        }
        return "\(quantity)"
    }
}

#if DEBUG
private let previewProduct = ProductDisplayItem(
    id: "1", brand: "Meadow Valley", description: "Organic Whole Milk, Half Gallon",
    category: "Dairy & Eggs", imageURL: nil, regularPrice: 4.49, promoPrice: nil, pricePerUnit: 0.70
)

#Preview("Row — needed") {
    ShoppingListRowView(
        item: ShoppingListItemDisplay(
            id: "1", product: previewProduct,
            aisle: AisleLocationDisplay(description: "Dairy", side: "Left", shelfNumber: "3"),
            quantityRequested: 2
        ),
        section: .needed
    )
    .padding()
}

#Preview("Row — needed, low stock") {
    ShoppingListRowView(
        item: ShoppingListItemDisplay(id: "1", product: previewProduct, aisle: nil, stock: .lowStock),
        section: .needed
    )
    .padding()
}

#Preview("Row — needed, out of stock, partly picked") {
    ShoppingListRowView(
        item: ShoppingListItemDisplay(
            id: "1", product: previewProduct, aisle: nil,
            quantityRequested: 2, quantityPicked: 1, stock: .outOfStock
        ),
        section: .needed
    )
    .padding()
}

#Preview("Row — picked, on promo") {
    ShoppingListRowView(
        item: ShoppingListItemDisplay(
            id: "2",
            product: ProductDisplayItem(
                id: "2", brand: "Golden Fields", description: "2% Reduced Fat Milk, Gallon",
                category: "Dairy & Eggs", imageURL: nil, regularPrice: 3.79, promoPrice: 2.99, pricePerUnit: 0.23
            ),
            aisle: AisleLocationDisplay(description: "Dairy", side: "Left", shelfNumber: "2"),
            quantityPicked: 1
        ),
        section: .picked
    )
    .padding()
}
#endif
