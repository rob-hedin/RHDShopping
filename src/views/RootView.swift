import SwiftUI
import RHKrogerAPI

/// Connects the screens: the main screen, the product picker (a sheet), the
/// shopping list (full screen), and History and Settings (pushed).
///
/// It's handed its dependencies instead of making them, so the `App` can
/// decide where the client, the saved lists and the store status come from.
/// Wrap it in a `LaunchGate` to show the splash while those are readied.
struct RootView: View {
    let client: KrogerClient
    @ObservedObject var library: ShoppingListLibraryModel
    let status: StoreStatus
    let onRequestLocation: () -> Void
    let onChooseStore: () -> Void

    @StateObject private var list: ShoppingListViewModel
    @State private var path: [Destination] = []
    @State private var search: SearchRequest?
    @State private var showingList = false
    @State private var detailItem: ProductDisplayItem?
    @State private var recents = RecentSearches().terms

    enum Destination: Hashable {
        case history, settings
    }

    private struct SearchRequest: Identifiable {
        let term: String
        var id: String { term }
    }

    init(
        client: KrogerClient,
        library: ShoppingListLibraryModel,
        status: StoreStatus,
        onRequestLocation: @escaping () -> Void,
        onChooseStore: @escaping () -> Void
    ) {
        self.client = client
        self.library = library
        self.status = status
        self.onRequestLocation = onRequestLocation
        self.onChooseStore = onChooseStore
        _list = StateObject(wrappedValue: ShoppingListViewModel(
            library: library, mode: status.isInStore ? .inStore : .planning
        ))
    }

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
                onChooseStore: onChooseStore,
                onRequestLocation: onRequestLocation
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .history:
                    HistoryListView(library: library, retentionMonths: HistoryRetention.months())
                case .settings:
                    SettingsView(library: library)
                }
            }
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

    private var shoppingList: some View {
        ShoppingListView(
            viewModel: list,
            storeName: status.store?.name,
            onBack: { showingList = false },
            onScan: {},
            onChangeStore: onChooseStore,
            onViewDetails: { item in
                // Show details over the list, not instead of it.
                detailItem = item.product
            }
        )
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
