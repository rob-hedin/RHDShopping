import SwiftUI

/// The shopping list: every product the person has added, split into
/// Needed and Picked, each with its own total.
///
/// There's no "accept"/"commit" action here. Tapping a row opens a dialog
/// to say how many were picked, and confirming takes effect right away.
/// The chrome beyond the list is a way back, a list-options menu, and scan.
struct ShoppingListView: View {
    @StateObject private var viewModel: ShoppingListViewModel
    let title: String
    let onBack: () -> Void
    /// Scanning itself isn't built yet - this just reserves the entry point
    /// so the screen's chrome is in place before the camera/barcode work is.
    let onScan: () -> Void

    init(
        viewModel: @autoclosure @escaping () -> ShoppingListViewModel,
        title: String = "Shopping List",
        onBack: @escaping () -> Void,
        onScan: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.title = title
        self.onBack = onBack
        self.onScan = onScan
    }

    @State private var pickRequest: PickRequest?

    var body: some View {
        NavigationStack {
            list
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: onBack) {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        optionsMenu
                        Button(action: onScan) {
                            Image(systemName: "barcode.viewfinder")
                        }
                        .accessibilityLabel("Scan item")
                    }
                }
                .sheet(item: $pickRequest) { request in
                    PickQuantitySheet(
                        request: request,
                        onConfirm: { quantity in
                            switch request.section {
                            case .needed: viewModel.pick(quantity, of: request.item)
                            case .picked: viewModel.setPickedQuantity(quantity, of: request.item)
                            }
                            pickRequest = nil
                        },
                        onMoveBack: {
                            viewModel.moveBackToNeeded(request.item)
                            pickRequest = nil
                        },
                        onCancel: { pickRequest = nil }
                    )
                }
        }
    }

    /// A menu rather than a settings screen: this preference only affects
    /// this screen's totals.
    private var optionsMenu: some View {
        Menu {
            Toggle("Include out-of-stock items in total", isOn: $viewModel.includesOutOfStockInTotal)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("List options")
    }

    private var list: some View {
        Group {
            if viewModel.items.isEmpty {
                ContentUnavailableView("Your list is empty", systemImage: "cart")
            } else {
                List {
                    section(.needed)
                    section(.picked)
                }
                .listStyle(.plain)
            }
        }
    }

    /// A section with its header, or nothing when it has no rows.
    @ViewBuilder
    private func section(_ section: ShoppingListSection) -> some View {
        let rows = viewModel.items(in: section)
        if !rows.isEmpty {
            Section {
                ForEach(rows) { item in
                    Button {
                        pickRequest = PickRequest(item: item, section: section)
                    } label: {
                        ShoppingListRowView(item: item, section: section)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                sectionHeader(section, count: rows.count)
            }
        }
    }

    private func sectionHeader(_ section: ShoppingListSection, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                Text("\(count)").font(.footnote).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(viewModel.totalText(for: section))
                        .fontWeight(section == .picked ? .semibold : .regular)
                        .foregroundStyle(section == .picked ? Color.primary : .secondary)
                    Text(section == .needed ? "to spend" : "spent").foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
            if section == .needed, viewModel.excludedOutOfStockCount > 0 {
                let count = viewModel.excludedOutOfStockCount
                Text(count == 1 ? "Excludes 1 out-of-stock item" : "Excludes \(count) out-of-stock items")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
    }
}

#if DEBUG
private let previewItems: [ShoppingListItemDisplay] = [
    ShoppingListItemDisplay(
        id: "1",
        product: ProductDisplayItem(id: "1", brand: "Meadow Valley", description: "Organic Whole Milk, Half Gallon", category: "Dairy & Eggs", imageURL: nil, regularPrice: 4.49, promoPrice: nil, pricePerUnit: 0.70),
        aisle: AisleLocationDisplay(description: "Dairy", side: "Left", shelfNumber: "3"),
        quantityRequested: 2
    ),
    ShoppingListItemDisplay(
        id: "3",
        product: ProductDisplayItem(id: "3", brand: "Sunrise Farms", description: "Lactose-Free Milk, Half Gallon", category: "Dairy & Eggs", imageURL: nil, regularPrice: 4.99, promoPrice: nil, pricePerUnit: 0.78),
        aisle: nil,
        stock: .lowStock
    ),
    ShoppingListItemDisplay(
        id: "4",
        product: ProductDisplayItem(id: "4", brand: "Clover Brook", description: "Almond Milk, Half Gallon", category: "Dairy & Eggs", imageURL: nil, regularPrice: 3.99, promoPrice: nil, pricePerUnit: 0.62),
        aisle: AisleLocationDisplay(description: "Dairy", side: "Right", shelfNumber: "4"),
        stock: .outOfStock
    ),
    ShoppingListItemDisplay(
        id: "2",
        product: ProductDisplayItem(id: "2", brand: "Golden Fields", description: "2% Reduced Fat Milk, Gallon", category: "Dairy & Eggs", imageURL: nil, regularPrice: 3.79, promoPrice: 2.99, pricePerUnit: 0.23),
        aisle: AisleLocationDisplay(description: "Dairy", side: "Left", shelfNumber: "2"),
        quantityPicked: 1
    ),
    ShoppingListItemDisplay(
        id: "5",
        product: ProductDisplayItem(id: "5", brand: "Honest Harvest", description: "Salted Butter, 1 lb", category: "Dairy & Eggs", imageURL: nil, regularPrice: 4.29, promoPrice: nil, pricePerUnit: 0.27),
        aisle: AisleLocationDisplay(description: "Dairy", side: "Right", shelfNumber: "1"),
        quantityRequested: 2,
        quantityPicked: 2
    ),
]

/// A throwaway defaults suite so a preview never reads or writes the real setting.
private func previewDefaults() -> UserDefaults {
    let defaults = UserDefaults(suiteName: "ShoppingListPreview")!
    defaults.removePersistentDomain(forName: "ShoppingListPreview")
    return defaults
}

#Preview("Shopping list") {
    ShoppingListView(
        viewModel: ShoppingListViewModel(items: previewItems, defaults: previewDefaults()),
        onBack: {}, onScan: {}
    )
}

#Preview("Out-of-stock excluded") {
    let viewModel = ShoppingListViewModel(items: previewItems, defaults: previewDefaults())
    viewModel.includesOutOfStockInTotal = false
    return ShoppingListView(viewModel: viewModel, onBack: {}, onScan: {})
}

#Preview("Empty list") {
    ShoppingListView(
        viewModel: ShoppingListViewModel(items: [], defaults: previewDefaults()),
        onBack: {}, onScan: {}
    )
}
#endif
