import SwiftUI

/// Finished lists, newest first. Meant to be pushed onto a navigation stack
/// (it relies on the stack's back button), and each row opens that list.
struct HistoryListView: View {
    @ObservedObject var library: ShoppingListLibraryModel
    /// How far back lists are kept, for the header and footer wording.
    let retentionMonths: Int

    var body: some View {
        Group {
            if library.history.isEmpty {
                ContentUnavailableView(
                    "No finished lists yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("When you finish shopping, the list is saved here.")
                )
            } else {
                List {
                    Section {
                        ForEach(library.history) { list in
                            NavigationLink {
                                HistoryDetailView(list: list, library: library)
                            } label: {
                                HistoryRowView(list: list)
                            }
                        }
                    } header: {
                        HStack {
                            Text(retentionTitle)
                            Spacer()
                            Text(library.history.count == 1 ? "1 list" : "\(library.history.count) lists")
                        }
                        .textCase(nil)
                    } footer: {
                        Text("Older lists are removed automatically. Change this in Settings.")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var retentionTitle: String {
        retentionMonths == 1 ? "Last month" : "Last \(retentionMonths) months"
    }
}

/// One finished list in the history: when, where, how much, and a flag when
/// something wasn't picked.
struct HistoryRowView: View {
    let list: ShoppingList

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dateText).font(.headline)
                Text(detailText).font(.footnote).foregroundStyle(.secondary)
                if notPickedCount > 0 {
                    Text("\(notPickedCount) not picked")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            Spacer(minLength: 0)
            Text(list.totalSpent, format: .currency(code: "USD")).font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var dateText: String {
        (list.completedAt ?? list.createdAt).formatted(date: .abbreviated, time: .omitted)
    }

    private var detailText: String {
        let count = list.items.count
        let items = count == 1 ? "1 item" : "\(count) items"
        return [list.storeName, items].compactMap { $0 }.joined(separator: " \u{B7} ")
    }

    private var notPickedCount: Int { list.unpickedItems.count }
}

#if DEBUG
private func previewItem(_ id: String, _ name: String, requested: Int, picked: Int, price: Decimal) -> ShoppingListItemDisplay {
    ShoppingListItemDisplay(
        id: id,
        product: ProductDisplayItem(id: id, brand: "Brand", description: name, category: nil, imageURL: nil, regularPrice: price, promoPrice: nil, pricePerUnit: nil),
        aisle: nil, quantityRequested: requested, quantityPicked: picked
    )
}

@MainActor
func previewHistoryLibrary() -> ShoppingListLibraryModel {
    func list(_ day: Int, _ items: [ShoppingListItemDisplay]) -> ShoppingList {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12))!
        return ShoppingList(createdAt: date, completedAt: date, storeName: "Main St", items: items)
    }
    let library = ShoppingListLibrary(
        active: ShoppingList(items: [previewItem("almond", "Almond Milk, Half Gallon", requested: 1, picked: 0, price: 3.99)]),
        history: [
            list(21, [
                previewItem("milk", "2% Reduced Fat Milk, Gallon", requested: 1, picked: 1, price: 2.99),
                previewItem("butter", "Salted Butter, 1 lb", requested: 2, picked: 2, price: 4.29),
                previewItem("almond", "Almond Milk, Half Gallon", requested: 1, picked: 0, price: 3.99),
            ]),
            list(14, [previewItem("eggs", "Large Eggs, 12 ct", requested: 1, picked: 1, price: 3.49)]),
        ]
    )
    return ShoppingListLibraryModel(store: InMemoryShoppingListStore(library), now: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5))!)
}

#Preview("History") {
    NavigationStack { HistoryListView(library: previewHistoryLibrary(), retentionMonths: 3) }
}

#Preview("History, empty") {
    NavigationStack {
        HistoryListView(
            library: ShoppingListLibraryModel(store: InMemoryShoppingListStore()),
            retentionMonths: 3
        )
    }
}
#endif
