import Combine
import Foundation
import RHKrogerAPI

/// Whether the person is building the list or standing in the store.
/// Planning shows estimates and hides stock; in-store shows real prices,
/// aisles and stock and lets them pick items.
enum ShoppingMode {
    case planning, inStore
}

/// Drives the shopping list screen.
///
/// The list itself lives in the `ShoppingListLibraryModel` (which saves it);
/// this view model reads from it and turns the person's taps into changes
/// on it. The one thing it keeps for itself is each product's live stock
/// level, which is never saved.
@MainActor
final class ShoppingListViewModel: ObservableObject {
    /// What the banner after finishing a list reports.
    struct FinishNotice: Equatable {
        let carriedCount: Int
        let finishedOn: Date
        let spent: Decimal
    }

    @Published var mode: ShoppingMode
    /// Whether items reported out of stock count toward the Needed total
    /// (in-store only). The person's choice, so it's remembered.
    @Published var includesOutOfStockInTotal: Bool {
        didSet { defaults.set(includesOutOfStockInTotal, forKey: Self.includesOutOfStockKey) }
    }
    @Published private(set) var finishNotice: FinishNotice?
    @Published private var stockByID: [String: ProductDetailDisplay.Stock]

    let library: ShoppingListLibraryModel
    private let defaults: UserDefaults
    private var libraryObservation: AnyCancellable?
    private static let includesOutOfStockKey = "shoppingList.includesOutOfStockInTotal"

    init(library: ShoppingListLibraryModel, mode: ShoppingMode = .inStore, defaults: UserDefaults = .standard) {
        self.library = library
        self.mode = mode
        self.defaults = defaults
        includesOutOfStockInTotal = defaults.object(forKey: Self.includesOutOfStockKey) as? Bool ?? true
        stockByID = Dictionary(
            library.active.items.compactMap { item in item.stock.map { (item.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        // Forward the library's changes so this screen redraws when the list does.
        libraryObservation = library.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    /// Seeds an in-memory list directly. This is what makes Previews
    /// possible: `KrogerProduct` has no public initializer, so a preview
    /// can't build a list from products.
    convenience init(
        items: [ShoppingListItemDisplay],
        mode: ShoppingMode = .inStore,
        defaults: UserDefaults = .standard
    ) {
        let library = ShoppingListLibraryModel(
            store: InMemoryShoppingListStore(ShoppingListLibrary(active: ShoppingList(items: items))),
            defaults: defaults
        )
        self.init(library: library, mode: mode, defaults: defaults)
    }

    // MARK: Items

    /// The active list with live stock folded in. Stock is hidden while
    /// planning, since it only means something at the store you're in.
    var items: [ShoppingListItemDisplay] {
        library.active.items.map { item in
            var item = item
            item.stock = mode == .inStore ? stockByID[item.id] : nil
            return item
        }
    }

    func items(in section: ShoppingListSection) -> [ShoppingListItemDisplay] {
        items.filter { $0.quantity(in: section) != nil }
    }

    // MARK: Totals

    /// What's left to spend. In-store, out-of-stock items are skipped when
    /// the person has turned that setting off; the row itself stays.
    var neededTotal: Decimal {
        items(in: .needed)
            .filter { includesOutOfStockInTotal || !$0.isOutOfStock }
            .reduce(Decimal(0)) { $0 + $1.total(in: .needed) }
    }

    /// What's been picked so far, counting every unit actually picked.
    var pickedTotal: Decimal {
        items(in: .picked).reduce(Decimal(0)) { $0 + $1.total(in: .picked) }
    }

    var excludedOutOfStockCount: Int {
        includesOutOfStockInTotal ? 0 : items(in: .needed).filter(\.isOutOfStock).count
    }

    func totalText(for section: ShoppingListSection) -> String {
        (section == .needed ? neededTotal : pickedTotal).formatted(.currency(code: "USD"))
    }

    // MARK: Adding

    /// Adds products from the picker. A product already on the list is left
    /// as it is (the same rule as copying from history).
    func add(_ products: [KrogerProduct]) {
        let incoming = products.map { $0.asShoppingListItem() }
        for item in incoming {
            if let stock = item.stock { stockByID[item.id] = stock }
        }
        library.updateActiveItems { items in
            for item in incoming where !items.contains(where: { $0.id == item.id }) {
                items.append(item)
            }
        }
    }

    // MARK: Picking (in store)

    /// Records `quantity` more picked units. Fewer than remaining leaves the
    /// rest in Needed; more is fine and just raises the picked count.
    func pick(_ quantity: Int, of item: ShoppingListItemDisplay) {
        guard quantity > 0 else { return }
        edit(item) { $0.quantityPicked += quantity }
    }

    /// Sets the picked quantity outright (the Picked row's dialog).
    func setPickedQuantity(_ quantity: Int, of item: ShoppingListItemDisplay) {
        edit(item) { $0.quantityPicked = max(quantity, 0) }
    }

    func moveBackToNeeded(_ item: ShoppingListItemDisplay) {
        setPickedQuantity(0, of: item)
    }

    // MARK: Editing (planning)

    func setRequestedQuantity(_ quantity: Int, of item: ShoppingListItemDisplay) {
        edit(item) { $0.quantityRequested = max(quantity, 1) }
    }

    func remove(_ item: ShoppingListItemDisplay) {
        library.updateActiveItems { $0.removeAll { $0.id == item.id } }
    }

    // MARK: Finishing

    /// What finishing would carry over; empty means no confirmation is needed.
    var leftovers: [ShoppingListItemDisplay] { library.leftovers }

    /// Finishes the list and starts the next one with the leftovers, then
    /// records a notice for the banner on the new list.
    func finish(storeName: String?, at date: Date = Date()) {
        let spent = library.active.totalSpent
        let carried = library.finishActiveList(storeName: storeName, at: date)
        finishNotice = FinishNotice(carriedCount: carried, finishedOn: date, spent: spent)
        // Stock belonged to the finished list's products; the carried ones
        // are refreshed the next time the store is checked.
        stockByID = [:]
    }

    func dismissFinishNotice() {
        finishNotice = nil
    }

    private func edit(_ item: ShoppingListItemDisplay, _ change: @escaping (inout ShoppingListItemDisplay) -> Void) {
        library.updateActiveItems { items in
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
            change(&items[index])
        }
    }
}
