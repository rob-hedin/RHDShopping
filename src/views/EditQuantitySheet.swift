import SwiftUI

/// The dialog for a row tapped while planning (not in the store): change how
/// many are needed, look at the product, or take it off the list. It's the
/// planning counterpart of `PickQuantitySheet`, which records picks in store.
struct EditQuantitySheet: View {
    let item: ShoppingListItemDisplay
    let storeName: String?
    let onUpdate: (Int) -> Void
    /// Nil hides the button, for callers that can't show product details.
    let onViewDetails: (() -> Void)?
    let onRemove: () -> Void

    @State private var quantity: Int

    init(
        item: ShoppingListItemDisplay,
        storeName: String?,
        onUpdate: @escaping (Int) -> Void,
        onViewDetails: (() -> Void)?,
        onRemove: @escaping () -> Void
    ) {
        self.item = item
        self.storeName = storeName
        self.onUpdate = onUpdate
        self.onViewDetails = onViewDetails
        self.onRemove = onRemove
        _quantity = State(initialValue: max(item.quantityRequested, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                if let brand = item.product.brand, !brand.isEmpty {
                    Text(brand).font(.caption).foregroundStyle(.secondary)
                }
                Text(item.product.description).font(.title3.bold())
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("How many do you need?").font(.subheadline.weight(.semibold))
                    Text("Total \(lineTotal) est.").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Stepper(value: $quantity, in: 1...99) {
                    Text("\(quantity)").font(.title2.weight(.semibold)).monospacedDigit()
                }
                .fixedSize()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Button { onUpdate(quantity) } label: {
                    Text("Update Quantity").frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let onViewDetails {
                    Button("View Product Details", action: onViewDetails).frame(minHeight: 44)
                }
                Button("Remove from List", role: .destructive, action: onRemove).frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .presentationDetents([.height(onViewDetails == nil ? 440 : 490)])
        .presentationDragIndicator(.visible)
    }

    private var subtitle: String {
        let price = item.product.effectivePrice.map { "\($0.formatted(.currency(code: "USD"))) each" } ?? "Price unavailable"
        return storeName.map { "\(price) \u{B7} estimated at \($0)" } ?? price
    }

    private var lineTotal: String {
        (Decimal(quantity) * (item.product.effectivePrice ?? 0)).formatted(.currency(code: "USD"))
    }
}
