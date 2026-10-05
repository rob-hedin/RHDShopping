import SwiftUI

/// What a tap on a row is asking about: which item, and from which section.
struct PickRequest: Identifiable {
    let item: ShoppingListItemDisplay
    let section: ShoppingListSection
    var id: String { "\(section.title)-\(item.id)" }
}

/// The dialog shown whenever a row is tapped. It always appears, so the
/// person can pick more than needed (a buy-one-get-one sale, say) or fewer.
///
/// From Needed it records `quantity` more picked units; from Picked it
/// sets the picked count, or puts everything back. Out-of-stock items open
/// it too: the stock flag is a hint, never a gate.
struct PickQuantitySheet: View {
    let item: ShoppingListItemDisplay
    let section: ShoppingListSection
    let onConfirm: (Int) -> Void
    let onMoveBack: () -> Void
    let onCancel: () -> Void

    @State private var quantity: Int

    init(
        request: PickRequest,
        onConfirm: @escaping (Int) -> Void,
        onMoveBack: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        item = request.item
        section = request.section
        self.onConfirm = onConfirm
        self.onMoveBack = onMoveBack
        self.onCancel = onCancel
        // Start from what's still needed, or from what's already picked.
        _quantity = State(initialValue: max(request.item.quantity(in: request.section) ?? 1, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            titleBlock
            if section == .needed, item.isOutOfStock { outOfStockNote }
            stepperCard
            if let hint { Text(hint).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4) }
            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .presentationDetents([.height(item.isOutOfStock && section == .needed ? 520 : 440)])
        .presentationDragIndicator(.visible)
    }

    // MARK: Pieces

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let brand = item.product.brand, !brand.isEmpty {
                Text(brand).font(.caption).foregroundStyle(.secondary)
            }
            Text(item.product.description).font(.title3.bold())
            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        let price = item.product.effectivePrice.map { "\($0.formatted(.currency(code: "USD"))) each" } ?? "Price unavailable"
        let context = section == .needed
            ? "Need \(item.quantityRemaining)"
            : "Picked \(item.quantityPicked)"
        return "\(price) \u{B7} \(context)"
    }

    private var outOfStockNote: some View {
        Text("**Out of stock here.** Stock info may be out of date, so you can still pick it.")
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var stepperCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(section == .needed ? "How many did you pick?" : "Picked quantity")
                    .font(.subheadline.weight(.semibold))
                Text("Total \(lineTotal)").font(.footnote).foregroundStyle(.secondary)
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
    }

    private var lineTotal: String {
        (Decimal(quantity) * (item.product.effectivePrice ?? 0)).formatted(.currency(code: "USD"))
    }

    /// Only the Needed dialog explains where a different count lands.
    private var hint: String? {
        guard section == .needed else { return nil }
        let remaining = item.quantityRemaining
        if quantity < remaining { return "\(remaining - quantity) will stay on Needed." }
        if quantity > remaining {
            return "\(quantity - remaining) more than needed. The Picked total counts all \(quantity)."
        }
        return nil
    }

    private var actions: some View {
        VStack(spacing: 6) {
            Button {
                onConfirm(quantity)
            } label: {
                Text(section == .needed ? "Mark \(quantity) as Picked" : "Update Quantity")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if section == .picked {
                Button("Move Back to Needed", role: .destructive, action: onMoveBack)
                    .frame(minHeight: 44)
            } else {
                Button("Cancel", action: onCancel)
                    .frame(minHeight: 44)
            }
        }
    }
}
