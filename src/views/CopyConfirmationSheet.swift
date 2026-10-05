import SwiftUI

/// Shows what copying items to the current list will do before it happens:
/// which are new, and which are already there (and so stay as they are).
struct CopyConfirmationSheet: View {
    let outcome: ShoppingListLibrary.CopyOutcome
    /// The current list's items, to show the quantity an existing entry keeps.
    let activeItems: [ShoppingListItemDisplay]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var total: Int { outcome.added.count + outcome.unchanged.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(total == 1 ? "Copy 1 item to your list?" : "Copy \(total) items to your list?")
                    .font(.title3.bold())
                Text(summary).font(.subheadline).foregroundStyle(.secondary)
            }

            List {
                ForEach(outcome.added) { item in
                    row(item, note: "New", trailing: "Qty \(item.quantityRequested)")
                }
                ForEach(outcome.unchanged) { item in
                    let keeps = activeItems.first { $0.id == item.id }?.quantityRequested ?? item.quantityRequested
                    row(item, note: "Already on your list \u{B7} not changed", trailing: "Stays Qty \(keeps)")
                }
            }
            .listStyle(.plain)

            VStack(spacing: 6) {
                Button(action: onConfirm) {
                    Text("Copy Items").frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(outcome.added.isEmpty)

                Button("Cancel", action: onCancel).frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var summary: String {
        let new = outcome.added.count
        let existing = outcome.unchanged.count
        switch (new, existing) {
        case (0, _): return "Everything is already on your list, so nothing will change."
        case (_, 0): return new == 1 ? "It\u{2019}s new to your list." : "All \(new) are new to your list."
        default:
            let newText = new == 1 ? "1 is new" : "\(new) are new"
            let existingText = existing == 1
                ? "1 is already on your list, so your list\u{2019}s entry stays as it is."
                : "\(existing) are already on your list, so your list\u{2019}s entries stay as they are."
            return "\(newText). \(existingText)"
        }
    }

    private func row(_ item: ShoppingListItemDisplay, note: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.product.description).font(.subheadline.weight(.medium))
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(trailing).font(.subheadline.weight(.semibold))
        }
        .listRowInsets(EdgeInsets())
    }
}
