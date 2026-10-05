import SwiftUI
import RHKrogerAPI

/// The shopping list: every product the person has added, split into
/// Needed and Picked, each with its own total.
///
/// There's no "accept"/"commit" action here. Tapping a row opens a dialog:
/// in the store it records how many were picked, while planning it edits
/// how many are needed. The chrome beyond the list is a way back, a
/// list-options menu (in store), and scan.
struct ShoppingListView: View {
    @StateObject private var viewModel: ShoppingListViewModel
    let title: String
    /// The store prices come from, for the banners and the planning dialog.
    let storeName: String?
    let onBack: () -> Void
    /// Scanning itself isn't built yet - this just reserves the entry point
    /// so the screen's chrome is in place before the camera/barcode work is.
    let onScan: () -> Void
    /// Nil hides "Change" on the in-store banner.
    let onChangeStore: (() -> Void)?
    /// Nil hides "View Product Details" in the planning dialog.
    let onViewDetails: ((ShoppingListItemDisplay) -> Void)?

    @State private var sheet: ListSheet?

    private enum ListSheet: Identifiable {
        case pick(PickRequest)
        case edit(ShoppingListItemDisplay)
        case finish

        var id: String {
            switch self {
            case .pick(let request): "pick-\(request.id)"
            case .edit(let item): "edit-\(item.id)"
            case .finish: "finish"
            }
        }
    }

    init(
        viewModel: @autoclosure @escaping () -> ShoppingListViewModel,
        title: String = "Shopping List",
        storeName: String? = nil,
        onBack: @escaping () -> Void,
        onScan: @escaping () -> Void,
        onChangeStore: (() -> Void)? = nil,
        onViewDetails: ((ShoppingListItemDisplay) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.title = title
        self.storeName = storeName
        self.onBack = onBack
        self.onScan = onScan
        self.onChangeStore = onChangeStore
        self.onViewDetails = onViewDetails
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modeBanner
                if let notice = viewModel.finishNotice { finishBanner(notice) }
                list
            }
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
                    if viewModel.mode == .inStore { optionsMenu }
                    Button(action: onScan) {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .accessibilityLabel("Scan item")
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .pick(let request): pickSheet(request)
                case .edit(let item): editSheet(item)
                case .finish: finishSheet
                }
            }
        }
    }

    // MARK: Banners

    @ViewBuilder
    private var modeBanner: some View {
        switch viewModel.mode {
        case .inStore:
            HStack(spacing: 10) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("**Shopping at \(storeName ?? "your store")** \u{B7} prices, aisles and stock for this store")
                    .font(.footnote)
                Spacer(minLength: 0)
                if let onChangeStore {
                    Button("Change", action: onChangeStore).font(.footnote.weight(.semibold))
                }
            }
            .padding(.horizontal).padding(.vertical, 6)
            .background(Color.green.opacity(0.14), ignoresSafeAreaEdges: [])
        case .planning:
            Text("Prices from \(storeName ?? "your nearest store"). Stock and aisles show when you\u{2019}re in the store.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), ignoresSafeAreaEdges: [])
        }
    }

    private func finishBanner(_ notice: ShoppingListViewModel.FinishNotice) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.right")
            Text(finishBannerText(notice)).font(.footnote)
            Spacer(minLength: 0)
            Button {
                viewModel.dismissFinishNotice()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.12), ignoresSafeAreaEdges: [])
    }

    private func finishBannerText(_ notice: ShoppingListViewModel.FinishNotice) -> String {
        let spent = notice.spent.formatted(.currency(code: "USD"))
        let date = notice.finishedOn.formatted(date: .abbreviated, time: .omitted)
        guard notice.carriedCount > 0 else {
            return "List finished and saved to History \u{B7} \(spent) spent."
        }
        let noun = notice.carriedCount == 1 ? "item" : "items"
        return "\(notice.carriedCount) \(noun) carried over from your list on \(date). Finished list saved to History \u{B7} \(spent) spent."
    }

    // MARK: Menu and finishing

    /// A menu rather than a settings screen: the out-of-stock preference only
    /// affects this screen's totals.
    private var optionsMenu: some View {
        Menu {
            Toggle("Include out-of-stock items in total", isOn: $viewModel.includesOutOfStockInTotal)
            Divider()
            Button("Finish Shopping", action: finishTapped)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("List options")
    }

    /// Asks first only when something would be carried over.
    private func finishTapped() {
        if viewModel.leftovers.isEmpty {
            viewModel.finish(storeName: storeName)
        } else {
            sheet = .finish
        }
    }

    private var finishSheet: some View {
        FinishConfirmationSheet(
            leftovers: viewModel.leftovers,
            onConfirm: {
                viewModel.finish(storeName: storeName)
                sheet = nil
            },
            onCancel: { sheet = nil }
        )
    }

    // MARK: List

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
                        sheet = viewModel.mode == .inStore
                            ? .pick(PickRequest(item: item, section: section))
                            : .edit(item)
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
                    Text(totalLabel(for: section)).foregroundStyle(.secondary)
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

    private func totalLabel(for section: ShoppingListSection) -> String {
        switch section {
        case .needed: viewModel.mode == .planning ? "estimated" : "to spend"
        case .picked: "spent"
        }
    }

    // MARK: Sheets

    private func pickSheet(_ request: PickRequest) -> some View {
        PickQuantitySheet(
            request: request,
            onConfirm: { quantity in
                switch request.section {
                case .needed: viewModel.pick(quantity, of: request.item)
                case .picked: viewModel.setPickedQuantity(quantity, of: request.item)
                }
                sheet = nil
            },
            onMoveBack: {
                viewModel.moveBackToNeeded(request.item)
                sheet = nil
            },
            onCancel: { sheet = nil }
        )
    }

    private func editSheet(_ item: ShoppingListItemDisplay) -> some View {
        EditQuantitySheet(
            item: item,
            storeName: storeName,
            onUpdate: { quantity in
                viewModel.setRequestedQuantity(quantity, of: item)
                sheet = nil
            },
            onViewDetails: onViewDetails.map { show in
                {
                    sheet = nil
                    show(item)
                }
            },
            onRemove: {
                viewModel.remove(item)
                sheet = nil
            }
        )
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
