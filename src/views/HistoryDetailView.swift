import SwiftUI

/// A finished list, read-only, with two ways to reuse it: copy the whole
/// thing to the current list, or tap Select and copy just some items.
///
/// Rows are split into Picked and Not picked (what actually happened), and
/// prices are the ones recorded when the list was finished.
struct HistoryDetailView: View {
    let list: ShoppingList
    @ObservedObject var library: ShoppingListLibraryModel

    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var pendingCopy: [ShoppingListItemDisplay]?
    @State private var copiedMessage: String?

    private var pickedItems: [ShoppingListItemDisplay] { list.items.filter { $0.quantityPicked > 0 } }
    private var notPickedItems: [ShoppingListItemDisplay] { list.items.filter { $0.quantityPicked == 0 } }

    var body: some View {
        List {
            summary
            section("Picked", items: pickedItems, trailing: list.totalSpent.formatted(.currency(code: "USD")))
            section("Not picked", items: notPickedItems, trailing: nil)
        }
        .listStyle(.plain)
        .navigationTitle((list.completedAt ?? list.createdAt).formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSelecting)
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) { copyBar }
        .overlay(alignment: .top) { toast }
        .sheet(item: Binding(get: { pendingCopy.map(CopyRequest.init) }, set: { if $0 == nil { pendingCopy = nil } })) { request in
            CopyConfirmationSheet(
                outcome: library.previewCopy(request.items),
                activeItems: library.active.items,
                onConfirm: { confirmCopy(request.items) },
                onCancel: { pendingCopy = nil }
            )
        }
    }

    // MARK: Pieces

    private var summary: some View {
        HStack {
            Text(list.storeName ?? "").foregroundStyle(.secondary)
            Spacer()
            Text("\(list.totalSpent.formatted(.currency(code: "USD"))) spent").fontWeight(.semibold)
        }
        .font(.footnote)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func section(_ title: String, items: [ShoppingListItemDisplay], trailing: String?) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    Button { rowTapped(item) } label: { row(item) }
                        .buttonStyle(.plain)
                        .allowsHitTesting(isSelecting)
                }
            } header: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                    Text("\(items.count)").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    if let trailing { Text(trailing).font(.footnote).foregroundStyle(.secondary) }
                }
                .textCase(nil)
            }
        }
    }

    private func row(_ item: ShoppingListItemDisplay) -> some View {
        HStack(spacing: 14) {
            if isSelecting {
                Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selectedIDs.contains(item.id) ? Color.accentColor : Color(.tertiaryLabel))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.product.description).font(.subheadline.weight(.medium))
                Text(priceLine(item)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("Qty \(quantity(item))").font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelecting && selectedIDs.contains(item.id) ? .isSelected : [])
    }

    /// What was picked, or what was wanted for something that wasn't.
    private func quantity(_ item: ShoppingListItemDisplay) -> Int {
        item.quantityPicked > 0 ? item.quantityPicked : item.quantityRequested
    }

    private func priceLine(_ item: ShoppingListItemDisplay) -> String {
        let price = item.product.effectivePrice.map { "\($0.formatted(.currency(code: "USD"))) each" }
        return [item.product.brand, price].compactMap { $0 }.joined(separator: " \u{B7} ")
    }

    // MARK: Toolbar and bottom bar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { endSelecting() }
            }
            ToolbarItem(placement: .principal) {
                Text(selectedIDs.count == 1 ? "1 Selected" : "\(selectedIDs.count) Selected").font(.headline)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(selectedIDs.count == list.items.count ? "Select None" : "Select All") {
                    selectedIDs = selectedIDs.count == list.items.count ? [] : Set(list.items.map(\.id))
                }
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button("Select") { isSelecting = true }
                    .disabled(list.items.isEmpty)
            }
        }
    }

    private var copyBar: some View {
        VStack(spacing: 6) {
            Button {
                pendingCopy = isSelecting ? list.items.filter { selectedIDs.contains($0.id) } : list.items
            } label: {
                Text(copyTitle).frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(list.items.isEmpty || (isSelecting && selectedIDs.isEmpty))

            if !isSelecting {
                Text("Copies the quantities you originally needed. Items already on your list aren\u{2019}t changed.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(.bar)
    }

    private var copyTitle: String {
        isSelecting ? "Copy \(selectedIDs.count) to Current List" : "Copy to Current List"
    }

    @ViewBuilder
    private var toast: some View {
        if let copiedMessage {
            Text(copiedMessage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Actions

    private func rowTapped(_ item: ShoppingListItemDisplay) {
        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
    }

    private func endSelecting() {
        isSelecting = false
        selectedIDs = []
    }

    private func confirmCopy(_ items: [ShoppingListItemDisplay]) {
        let outcome = library.copyToActiveList(items)
        pendingCopy = nil
        endSelecting()
        let added = outcome.added.count
        withAnimation {
            copiedMessage = added == 0 ? "Nothing new to copy" : (added == 1 ? "Copied 1 item" : "Copied \(added) items")
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { copiedMessage = nil }
        }
    }
}

/// Wraps a set of items so a sheet can be presented for them.
private struct CopyRequest: Identifiable {
    let id = UUID()
    let items: [ShoppingListItemDisplay]
}

#if DEBUG
#Preview("History detail") {
    let library = previewHistoryLibrary()
    return NavigationStack { HistoryDetailView(list: library.history[0], library: library) }
}
#endif
