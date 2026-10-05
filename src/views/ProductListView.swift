import SwiftUI
import RHKrogerAPI

/// Product search results, for picking one or more items to add to a
/// shopping list. Designed to be presented as a sheet: it owns its own
/// navigation bar (Back) and a pinned bottom bar (Add to List), so it
/// doesn't depend on being pushed in an existing `NavigationStack`.
///
/// The store is already known by the time this screen is shown, so there's
/// no location picker or location info here — `locationID` only goes along
/// for the search call. Likewise there's no cart and no IDs/UPCs on screen;
/// those stay on `KrogerProduct`, available to whoever handles
/// `onAddSelected`.
///
/// Tapping a row (outside its checkbox) pushes the product's detail screen
/// onto this view's own stack. "Add to List" there just checks the row (at
/// the quantity chosen there) and returns here, so adding still happens in
/// one place: the footer button. A checked row shows a quantity stepper.
struct ProductListView: View {
    @StateObject private var viewModel: ProductListViewModel
    @State private var path: [ProductDisplayItem] = []
    let onBack: () -> Void
    let onAddSelected: ([SelectedProduct]) -> Void
    /// Builds the detail screen's view model for a tapped row. The caller
    /// owns the client (and store), so the list doesn't need to.
    let makeDetailViewModel: (ProductDisplayItem) -> ProductDetailViewModel

    init(
        viewModel: @autoclosure @escaping () -> ProductListViewModel,
        makeDetailViewModel: @escaping (ProductDisplayItem) -> ProductDetailViewModel,
        onBack: @escaping () -> Void,
        onAddSelected: @escaping ([SelectedProduct]) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.makeDetailViewModel = makeDetailViewModel
        self.onBack = onBack
        self.onAddSelected = onAddSelected
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                resultsHeader
                Divider()
                resultsList
            }
            .navigationTitle(viewModel.searchTerm.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
            .navigationDestination(for: ProductDisplayItem.self) { item in
                ProductDetailView(
                    viewModel: makeDetailViewModel(item),
                    onAddToList: { _, quantity in
                        viewModel.select(item, quantity: quantity)
                        path.removeAll()
                    }
                )
            }
            .task { await viewModel.loadResults() }
            .alert("Something went wrong", isPresented: isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.errorMessage = nil }
            }
        )
    }

    private var resultsHeader: some View {
        HStack(spacing: 8) {
            Text(resultCountText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var resultCountText: String {
        let count = viewModel.items.count
        let noun = count == 1 ? "result" : "results"
        return "\(count) \(noun) for \u{201C}\(viewModel.searchTerm)\u{201D}"
    }

    private var resultsList: some View {
        Group {
            if viewModel.items.isEmpty && !viewModel.isLoading {
                ContentUnavailableView.search
            } else {
                List(viewModel.items) { item in
                    ProductRowView(
                        item: item,
                        isSelected: viewModel.isSelected(item),
                        quantity: viewModel.quantity(for: item),
                        onToggle: { viewModel.toggleSelection(item) },
                        onQuantityChange: { viewModel.setQuantity($0, for: item) },
                        onOpen: { path.append(item) }
                    )
                }
                .listStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(footerText)
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("Add to List") {
                onAddSelected(viewModel.confirmSelection())
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedCount == 0)
        }
        .padding()
        .background(.bar)
    }

    private var footerText: String {
        let items = viewModel.selectedCount == 1 ? "1 item selected" : "\(viewModel.selectedCount) items selected"
        // Mention units only when they differ from the item count.
        return viewModel.selectedUnitCount == viewModel.selectedCount ? items : "\(items) \u{B7} \(viewModel.selectedUnitCount) total"
    }
}

#if DEBUG
private struct PreviewProductSearching: ProductSearching {
    func search(
        term: String?, locationID: String?, productIDs: [String], brands: [String],
        fulfillment: Set<KrogerFulfillment>, start: Int?, limit: Int?
    ) async throws -> [KrogerProduct] {
        [] // Previews seed `items` directly; this is never actually called.
    }
}

private struct PreviewProductFetching: ProductFetching {
    func product(id: String, locationID: String?) async throws -> KrogerProduct {
        throw CancellationError() // Previews never open the detail screen's network call.
    }
}

@MainActor private func previewDetailViewModel(_ item: ProductDisplayItem) -> ProductDetailViewModel {
    ProductDetailViewModel(productID: item.id, locationID: "01400943", products: PreviewProductFetching())
}

private let previewItems: [ProductDisplayItem] = [
    ProductDisplayItem(id: "1", brand: "Meadow Valley", description: "Organic Whole Milk, Half Gallon", category: "Dairy & Eggs", imageURL: nil, regularPrice: 4.49, promoPrice: nil, pricePerUnit: 0.70),
    ProductDisplayItem(id: "2", brand: "Golden Fields", description: "2% Reduced Fat Milk, Gallon", category: "Dairy & Eggs", imageURL: nil, regularPrice: 3.79, promoPrice: 2.99, pricePerUnit: 0.23),
    ProductDisplayItem(id: "3", brand: "Sunrise Farms", description: "Lactose-Free Milk, Half Gallon", category: "Dairy & Eggs", imageURL: nil, regularPrice: 4.99, promoPrice: nil, pricePerUnit: 0.78),
    ProductDisplayItem(id: "4", brand: "Honest Harvest", description: "Whole Milk, Quart", category: "Dairy & Eggs", imageURL: nil, regularPrice: 2.29, promoPrice: nil, pricePerUnit: 0.57),
]

#Preview("No selection") {
    ProductListView(
        viewModel: ProductListViewModel(
            searchTerm: "milk",
            locationID: "01400943",
            products: PreviewProductSearching(),
            initialItems: previewItems
        ),
        makeDetailViewModel: previewDetailViewModel,
        onBack: {},
        onAddSelected: { _ in }
    )
}

#Preview("Some selected") {
    let viewModel = ProductListViewModel(
        searchTerm: "milk",
        locationID: "01400943",
        products: PreviewProductSearching(),
        initialItems: previewItems
    )
    viewModel.toggleSelection(previewItems[1])
    viewModel.toggleSelection(previewItems[3])
    return ProductListView(viewModel: viewModel, makeDetailViewModel: previewDetailViewModel, onBack: {}, onAddSelected: { _ in })
}
#endif
