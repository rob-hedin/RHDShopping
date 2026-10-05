import Foundation
import RHKrogerAPI

/// Drives the product picker screen: runs the search, holds the results as
/// display-ready items, and tracks which rows the person has checked.
@MainActor
final class ProductListViewModel: ObservableObject {
    @Published private(set) var items: [ProductDisplayItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var selectedIDs: Set<String> = []

    let searchTerm: String

    private let locationID: String
    private let searchLimit: Int
    private let products: ProductSearching

    /// The full API models behind `items`, keyed by product ID, so a
    /// selection can be handed back with everything the shopping list
    /// might eventually need (not just what this screen displays).
    private var sourceProducts: [String: KrogerProduct] = [:]

    /// - Parameter initialItems: Lets a preview or test seed the list
    ///   directly, bypassing the network call `loadResults()` would make.
    init(
        searchTerm: String,
        locationID: String,
        products: ProductSearching,
        searchLimit: Int = 50,
        initialItems: [ProductDisplayItem] = []
    ) {
        self.searchTerm = searchTerm
        self.locationID = locationID
        self.products = products
        self.searchLimit = searchLimit
        self.items = initialItems
    }

    var selectedCount: Int { selectedIDs.count }

    func isSelected(_ item: ProductDisplayItem) -> Bool {
        selectedIDs.contains(item.id)
    }

    func toggleSelection(_ item: ProductDisplayItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    /// Checks the row if it isn't already; unlike `toggleSelection`, calling
    /// it twice leaves it checked (used when adding from the detail screen).
    func select(_ item: ProductDisplayItem) {
        selectedIDs.insert(item.id)
    }

    /// The full-detail products behind the checked rows, for the caller to
    /// hand off to the shopping list.
    func confirmSelection() -> [KrogerProduct] {
        selectedIDs.compactMap { sourceProducts[$0] }
    }

    func loadResults() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let results = try await products.search(term: searchTerm, locationID: locationID, limit: searchLimit)
            sourceProducts = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
            items = results.map { $0.asDisplayItem() }
            // Drop selections for rows that didn't come back in a reload.
            selectedIDs = selectedIDs.intersection(sourceProducts.keys)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't load results. Please try again."
        }
    }
}
