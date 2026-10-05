import SwiftUI

/// One row in the product picker list: thumbnail, brand/description/category,
/// price, and a checkbox — the card-style layout from the design exploration.
struct ProductRowView: View {
    let item: ProductDisplayItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            details
            Spacer(minLength: 0)
            selectionButton
        }
        .padding(.vertical, 6)
    }

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .frame(width: 72, height: 72)
            .overlay {
                AsyncImage(url: item.imageURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(8)
                    } else {
                        Image(systemName: "bag")
                            .font(.system(size: 22))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let brand = item.brand, !brand.isEmpty {
                Text(brand.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
            }

            Text(item.description)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let category = item.category {
                Text(category)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.secondarySystemBackground), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 1) {
                priceRow
                if let perUnit = item.pricePerUnitText {
                    Text(perUnit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 1)
        }
    }

    /// Promo active: promo price emphasized, regular price struck through
    /// beside it. No promo: just the regular price. Neither: a fallback note.
    @ViewBuilder
    private var priceRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if item.isOnPromo, let promoText = item.promoPriceText {
                Text(promoText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red)
                if let regularText = item.regularPriceText {
                    Text(regularText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .strikethrough()
                }
            } else if let regularText = item.regularPriceText {
                Text(regularText)
                    .font(.subheadline.weight(.bold))
            } else {
                Text("Price unavailable")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectionButton: some View {
        Button(action: onToggle) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isSelected ? "Deselect" : "Select"))
        .accessibilityValue(Text(item.description))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Row — regular price") {
    ProductRowView(
        item: ProductDisplayItem(
            id: "1",
            brand: "Meadow Valley",
            description: "Organic Whole Milk, Half Gallon",
            category: "Dairy & Eggs",
            imageURL: nil,
            regularPrice: 4.49,
            promoPrice: nil,
            pricePerUnit: 0.70
        ),
        isSelected: false,
        onToggle: {}
    )
    .padding()
}

#Preview("Row — on promo, selected") {
    ProductRowView(
        item: ProductDisplayItem(
            id: "2",
            brand: "Honest Harvest",
            description: "Whole Milk, Quart",
            category: "Dairy & Eggs",
            imageURL: nil,
            regularPrice: 2.29,
            promoPrice: 1.79,
            pricePerUnit: 0.45
        ),
        isSelected: true,
        onToggle: {}
    )
    .padding()
}

#Preview("Row — price unavailable") {
    ProductRowView(
        item: ProductDisplayItem(
            id: "3",
            brand: "Clover Brook",
            description: "Chocolate Milk, Half Gallon",
            category: "Dairy & Eggs",
            imageURL: nil,
            regularPrice: nil,
            promoPrice: nil,
            pricePerUnit: nil
        ),
        isSelected: false,
        onToggle: {}
    )
    .padding()
}
