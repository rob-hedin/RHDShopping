import SwiftUI
import RHKrogerAPI

/// Connects the screens: the main screen, the product picker (a sheet), the
/// shopping list (full screen), and History and Settings (pushed).
///
/// It's handed its dependencies instead of making them, so the `App` can
/// decide where the client, the saved lists and the store locator come from.
/// Wrap it in a `LaunchGate` to show the splash while those are readied.
struct RootView: View {
    let client: KrogerClient
    @ObservedObject var library: ShoppingListLibraryModel
    @ObservedObject var locator: StoreLocator

    @StateObject private var list: ShoppingListViewModel
    @State private var path: [Destination] = []
    @State private var search: SearchRequest?
    @State private var showingList = false
    /// The store picker can open from the main screen or over the list, and a
    /// sheet can't open from a screen that's covered, so each has its own flag.
    @State private var showingStorePicker = false
    @State private var showingStorePickerOverList = false
    @State private var detailItem: ProductDisplayItem?
    @State private var recents = RecentSearches().terms

    enum Destination: Hashable {
        case history, settings
    }

    private struct SearchRequest: Identifiable {
        let term: String
        var id: String { term }
    }

    init(client: KrogerClient, library: ShoppingListLibraryModel, locator: StoreLocator) {
        self.client = client
        self.library = library
        self.locator = locator
        _list = StateObject(wrappedValue: ShoppingListViewModel(
            library: library, mode: locator.status.isInStore ? .inStore : .planning
        ))
    }

    private var status: StoreStatus { locator.status }

    var body: some View {
        NavigationStack(path: $path) {
            MainView(
                list: list,
                status: status,
                recents: recents,
                onSearch: startSearch,
                onOpenList: { showingList = true },
                onOpenHistory: { path.append(.history) },
                onOpenSettings: { path.append(.settings) },
                onChooseStore: { showingStorePicker = true },
                onRequestLocation: { Task { await locator.requestPermission() } }
            )
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingStorePicker) { storePicker(dismiss: { showingStorePicker = false }) }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .history:
                    HistoryListView(library: library, retentionMonths: HistoryRetention.months())
                case .settings:
                    SettingsView(library: library)
                }
            }
        }
        // Prices, aisles and stock belong to a store, so bring the list up to
        // date on launch and whenever the store changes. `.task(id:)` cancels
        // the previous lookup when the store changes again.
        .task(id: status.store?.id) {
            guard let store = status.store else { return }
            await list.refresh(for: store, using: .kroger(client.products))
        }
        // The list follows whether the person is in the store.
        .onChange(of: status.isInStore) { _, isInStore in
            list.mode = isInStore ? .inStore : .planning
        }
        .sheet(item: $search) { request in
            if let store = status.store { picker(term: request.term, store: store) }
        }
        .fullScreenCover(isPresented: $showingList) { shoppingList }
    }

    // MARK: Presentations

    private func startSearch(_ term: String) {
        guard status.store != nil else { return }
        RecentSearches().record(term)
        recents = RecentSearches().terms
        search = SearchRequest(term: term)
    }

    private func picker(term: String, store: StoreRef) -> some View {
        ProductListView(
            viewModel: ProductListViewModel(searchTerm: term, locationID: store.id, products: client.products),
            makeDetailViewModel: { item in
                ProductDetailViewModel(productID: item.id, locationID: store.id, products: client.products)
            },
            onBack: { search = nil },
            onAddSelected: { products in
                list.add(products)
                search = nil
            }
        )
    }

    private func storePicker(dismiss: @escaping () -> Void) -> some View {
        StorePickerView(
            viewModel: StorePickerViewModel(
                search: KrogerStoreSearch(locations: client.locations),
                userPoint: { locator.lastKnownPoint }
            ),
            selected: status.store,
            onNearMe: {
                await locator.requestPermission()
                return locator.lastKnownPoint
            },
            onSelect: { store in
                locator.choose(store)
                dismiss()
            },
            onDone: dismiss
        )
    }

    private var shoppingList: some View {
        ShoppingListView(
            viewModel: list,
            storeName: status.store?.name,
            onBack: { showingList = false },
            onScan: {},
            onChangeStore: { showingStorePickerOverList = true },
            onViewDetails: { item in
                // Show details over the list, not instead of it.
                detailItem = item.product
            }
        )
        .sheet(isPresented: $showingStorePickerOverList) {
            storePicker(dismiss: { showingStorePickerOverList = false })
        }
        .sheet(item: $detailItem) { item in
            NavigationStack {
                ProductDetailView(
                    viewModel: ProductDetailViewModel(
                        productID: item.id, locationID: status.store?.id ?? "", products: client.products
                    ),
                    onAddToList: nil
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { detailItem = nil } }
                }
            }
        }
    }
}
