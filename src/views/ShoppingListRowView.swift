import SwiftUI

/// One row on the shopping list: where to find it in the store, then
/// brand/description, then price — in that order. No category, no
/// thumbnail; this list stays compact.
struct ShoppingListRowView: View {
    let item: ShoppingListItemDisplay
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            details
            Spacer(minLength: 0)
            pickedUpButton
        }
        .padding(.vertical, 8)
        .opacity(item.isPickedUp ? 0.5 : 1)
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

    private var pickedUpButton: some View {
        Button(action: onToggle) {
            Image(systemName: item.isPickedUp ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(item.isPickedUp ? Color.accentColor : Color(.tertiaryLabel))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.isPickedUp ? "Mark not picked up" : "Mark picked up"))
        .accessibilityValue(Text(item.product.description))
        .accessibilityAddTraits(item.isPickedUp ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Row — not picked up") {
    ShoppingListRowView(
        item: ShoppingListItemDisplay(
            id: "1",
            product: ProductDisplayItem(
                id: "1", brand: "Meadow Valley", description: "Organic Whole Milk, Half Gallon",
                category: "Dairy & Eggs", imageURL: nil, regularPrice: 4.49, promoPrice: nil, pricePerUnit: 0.70
            ),
            aisle: AisleLocationDisplay(description: "Dairy", side: "Left", shelfNumber: "3"),
            isPickedUp: false
        ),
        onToggle: {}
    )
    .padding()
}

#Preview("Row — picked up, on promo") {
    ShoppingListRowView(
        item: ShoppingListItemDisplay(
            id: "2",
            product: ProductDisplayItem(
                id: "2", brand: "Golden Fields", description: "2% Reduced Fat Milk, Gallon",
                category: "Dairy & Eggs", imageURL: nil, regularPrice: 3.79, promoPrice: 2.99, pricePerUnit: 0.23
            ),
            aisle: AisleLocationDisplay(description: "Dairy", side: "Left", shelfNumber: "2"),
            isPickedUp: true
        ),
        onToggle: {}
    )
    .padding()
}

#Preview("Row — no aisle data") {
    ShoppingListRowView(
        item: ShoppingListItemDisplay(
            id: "3",
            product: ProductDisplayItem(
                id: "3", brand: "Clover Brook", description: "Chocolate Milk, Half Gallon",
                category: "Dairy & Eggs", imageURL: nil, regularPrice: 3.49, promoPrice: nil, pricePerUnit: 0.55
            ),
            aisle: nil,
            isPickedUp: false
        ),
        onToggle: {}
    )
    .padding()
}
