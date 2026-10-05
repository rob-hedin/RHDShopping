import SwiftUI

/// Shown when finishing a list that still has items to pick. It says what
/// will move to the next list and lets the person back out. A list with
/// nothing left over finishes without asking.
struct FinishConfirmationSheet: View {
    let leftovers: [ShoppingListItemDisplay]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Finish shopping?").font(.title3.bold())
                Text(summary).font(.subheadline).foregroundStyle(.secondary)
            }

            List(leftovers) { item in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.product.description).font(.subheadline.weight(.medium))
                        if let note = note(for: item) {
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(quantityText(for: item)).font(.subheadline.weight(.semibold))
                }
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)

            VStack(spacing: 6) {
                Button(action: onConfirm) {
                    Text("Finish & Start New List").frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Keep Shopping", action: onCancel).frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var summary: String {
        let count = leftovers.count
        return count == 1
            ? "1 item wasn\u{2019}t picked. It will move to your next list."
            : "\(count) items weren\u{2019}t picked. They\u{2019}ll move to your next list."
    }

    /// "1 of 2" when only part of the request was picked, else just what's left.
    private func quantityText(for item: ShoppingListItemDisplay) -> String {
        item.quantityPicked > 0 ? "\(item.quantityRemaining) of \(item.quantityRequested)" : "\(item.quantityRemaining)"
    }

    private func note(for item: ShoppingListItemDisplay) -> String? {
        var parts: [String] = []
        if let brand = item.product.brand, !brand.isEmpty { parts.append(brand) }
        if item.isOutOfStock { parts.append("was out of stock") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{B7} ")
    }
}

#if DEBUG
#Preview("Finish confirmation") {
    FinishConfirmationSheet(
        leftovers: [
            ShoppingListItemDisplay(
                id: "1",
                product: ProductDisplayItem(id: "1", brand: "Meadow Valley", description: "Organic Whole Milk, Half Gallon", category: nil, imageURL: nil, regularPrice: 4.49, promoPrice: nil, pricePerUnit: nil),
                aisle: nil, quantityRequested: 2, quantityPicked: 1
            ),
            ShoppingListItemDisplay(
                id: "2",
                product: ProductDisplayItem(id: "2", brand: "Clover Brook", description: "Almond Milk, Half Gallon", category: nil, imageURL: nil, regularPrice: 3.99, promoPrice: nil, pricePerUnit: nil),
                aisle: nil, stock: .outOfStock
            ),
        ],
        onConfirm: {}, onCancel: {}
    )
}
#endif
