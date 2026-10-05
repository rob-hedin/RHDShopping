import Foundation
import RHKrogerAPI

/// A product the person chose to add, with how many.
struct SelectedProduct {
    let product: KrogerProduct
    let quantity: Int
}

/// Drives the product picker screen: runs the search, holds the results as
/// display-ready items, and tracks which rows the person has checked and how
/// many of each they want.
@MainActor
final class ProductListViewModel: ObservableObject {
    @Published private(set) var items: [ProductDisplayItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var selectedIDs: Set<String> = []
    /// How many of each checked product to add. Every checked row has one.
    @Published private(set) var quantities: [String: Int] = [:]

    /// The most of one product that can be added at once.
    static let quantityRange = 1...99

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

    /// Units across every checked product (two milks and a butter is 3).
    var selectedUnitCount: Int { selectedIDs.reduce(0) { $0 + quantity(forID: $1) } }

    func isSelected(_ item: ProductDisplayItem) -> Bool {
        selectedIDs.contains(item.id)
    }

    /// How many of this row's product will be added; 1 until the person says otherwise.
    func quantity(for item: ProductDisplayItem) -> Int {
        quantity(forID: item.id)
    }

    private func quantity(forID id: String) -> Int {
        quantities[id] ?? 1
    }

    /// Changes how many to add, keeping it within `quantityRange`. Only
    /// affects a checked row.
    func setQuantity(_ quantity: Int, for item: ProductDisplayItem) {
        guard selectedIDs.contains(item.id) else { return }
        quantities[item.id] = min(max(quantity, Self.quantityRange.lowerBound), Self.quantityRange.upperBound)
    }

    func toggleSelection(_ item: ProductDisplayItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
            quantities[item.id] = nil
        } else {
            select(item)
        }
    }

    /// Checks the row if it isn't already, at `quantity`. Unlike
    /// `toggleSelection`, calling it twice leaves it checked (used when
    /// adding from the detail screen, which picks a quantity of its own).
    func select(_ item: ProductDisplayItem, quantity: Int = 1) {
        selectedIDs.insert(item.id)
        quantities[item.id] = min(max(quantity, Self.quantityRange.lowerBound), Self.quantityRange.upperBound)
    }

    /// The full-detail products behind the checked rows, each with its
    /// quantity, for the caller to hand off to the shopping list.
    func confirmSelection() -> [SelectedProduct] {
        selectedIDs.compactMap { id in
            sourceProducts[id].map { SelectedProduct(product: $0, quantity: quantity(forID: id)) }
        }
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
            quantities = quantities.filter { selectedIDs.contains($0.key) }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't load results. Please try again."
        }
    }
}
