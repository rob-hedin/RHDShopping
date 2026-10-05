import SwiftUI

/// The shopping list: every product the person has added, with where to
/// find it in the store and a checkbox for marking it picked up.
///
/// There's no "accept"/"commit" action here — checking an item off is the
/// whole interaction, and it takes effect right away. The only chrome this
/// screen needs beyond the list itself is a way back.
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                Divider()
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
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onScan) {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .accessibilityLabel("Scan item")
                }
            }
        }
    }

    private var progressHeader: some View {
        HStack {
            Text(progressText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(viewModel.runningTotalText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var progressText: String {
        let total = viewModel.items.count
        let noun = total == 1 ? "item" : "items"
        return "\(total) \(noun) \u{B7} \(viewModel.pickedUpCount) picked up"
    }

    private var list: some View {
        Group {
            if viewModel.items.isEmpty {
                ContentUnavailableView("Your list is empty", systemImage: "cart")
            } else {
                List(viewModel.items) { item in
                    ShoppingListRowView(item: item, onToggle: { viewModel.togglePickedUp(item) })
                }
                .listStyle(.plain)
            }
        }
    }
}

#if DEBUG
private let previewItems: [ShoppingListItemDisplay] = [
    ShoppingListItemDisplay(
        id: "1",
        product: ProductDisplayItem(id: "1", brand: "Meadow Valley", description: "Organic Whole Milk, Half Gallon", category: "Dairy & Eggs", imageURL: nil, regularPrice: 4.49, promoPrice: nil, pricePerUnit: 0.70),
        aisle: AisleLocationDisplay(description: "Dairy", side: "Left", shelfNumber: "3"),
        isPickedUp: false
    ),
    ShoppingListItemDisplay(
        id: "2",
        product: ProductDisplayItem(id: "2", brand: "Golden Fields", description: "2% Reduced Fat Milk, Gallon", category: "Dairy & Eggs", imageURL: nil, regularPrice: 3.79, promoPrice: 2.99, pricePerUnit: 0.23),
        aisle: AisleLocationDisplay(description: "Dairy", side: "Left", shelfNumber: "2"),
        isPickedUp: true
    ),
    ShoppingListItemDisplay(
        id: "3",
        product: ProductDisplayItem(id: "3", brand: "Sunrise Farms", description: "Lactose-Free Milk, Half Gallon", category: "Dairy & Eggs", imageURL: nil, regularPrice: 4.99, promoPrice: nil, pricePerUnit: 0.78),
        aisle: nil,
        isPickedUp: false
    ),
]

#Preview("Shopping list") {
    ShoppingListView(viewModel: ShoppingListViewModel(items: previewItems), onBack: {}, onScan: {})
}

#Preview("Empty list") {
    ShoppingListView(viewModel: ShoppingListViewModel(items: []), onBack: {}, onScan: {})
}
#endif
