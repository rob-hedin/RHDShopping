import Foundation
import RHKrogerAPI

/// Drives the shopping list screen.
///
/// Unlike the product picker, there's no network call and no "confirm" step
/// here: the products are already known (they came from the picker earlier),
/// and recording a pick takes effect immediately.
@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published private(set) var items: [ShoppingListItemDisplay]

    /// Whether items reported out of stock count toward the Needed total.
    /// The person's choice, so it's remembered between launches.
    @Published var includesOutOfStockInTotal: Bool {
        didSet { defaults.set(includesOutOfStockInTotal, forKey: Self.includesOutOfStockKey) }
    }

    private let defaults: UserDefaults
    private static let includesOutOfStockKey = "shoppingList.includesOutOfStockInTotal"

    /// Builds the list from products already on hand (e.g. what the picker
    /// screen's `onAddSelected` handed back), one of each, optionally
    /// restoring which ones were already picked up.
    init(products: [KrogerProduct], pickedUpProductIDs: Set<String> = [], defaults: UserDefaults = .standard) {
        self.defaults = defaults
        includesOutOfStockInTotal = defaults.object(forKey: Self.includesOutOfStockKey) as? Bool ?? true
        items = products.map {
            $0.asShoppingListItem(quantityPicked: pickedUpProductIDs.contains($0.id) ? 1 : 0)
        }
    }

    /// Seeds the list directly from display items. This is also what makes
    /// Previews possible: `KrogerProduct` has no public initializer, so a
    /// preview can't build the `products:` initializer's input.
    init(items: [ShoppingListItemDisplay], defaults: UserDefaults = .standard) {
        self.defaults = defaults
        includesOutOfStockInTotal = defaults.object(forKey: Self.includesOutOfStockKey) as? Bool ?? true
        self.items = items
    }

    // MARK: Sections

    /// Items with at least one still to pick, in list order.
    var neededItems: [ShoppingListItemDisplay] { items.filter { $0.quantity(in: .needed) != nil } }

    /// Items with at least one picked, in list order.
    var pickedItems: [ShoppingListItemDisplay] { items.filter { $0.quantity(in: .picked) != nil } }

    func items(in section: ShoppingListSection) -> [ShoppingListItemDisplay] {
        section == .needed ? neededItems : pickedItems
    }

    // MARK: Totals

    /// What's left to spend. Out-of-stock items are skipped when the person
    /// has turned that setting off; the row itself stays in the list.
    var neededTotal: Decimal {
        neededItems
            .filter { includesOutOfStockInTotal || !$0.isOutOfStock }
            .reduce(Decimal(0)) { $0 + $1.total(in: .needed) }
    }

    /// What's been picked so far, counting every unit actually picked
    /// (including any beyond what was requested).
    var pickedTotal: Decimal {
        pickedItems.reduce(Decimal(0)) { $0 + $1.total(in: .picked) }
    }

    /// How many Needed rows the Needed total currently leaves out.
    var excludedOutOfStockCount: Int {
        includesOutOfStockInTotal ? 0 : neededItems.filter(\.isOutOfStock).count
    }

    func totalText(for section: ShoppingListSection) -> String {
        (section == .needed ? neededTotal : pickedTotal).formatted(.currency(code: "USD"))
    }

    // MARK: Picking

    /// Records `quantity` more picked units for the product (the Needed
    /// row's dialog). Fewer than remaining leaves the rest in Needed; more
    /// than remaining is fine and just raises the picked count.
    func pick(_ quantity: Int, of item: ShoppingListItemDisplay) {
        guard quantity > 0, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].quantityPicked += quantity
    }

    /// Sets the product's picked quantity outright (the Picked row's dialog).
    func setPickedQuantity(_ quantity: Int, of item: ShoppingListItemDisplay) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].quantityPicked = max(quantity, 0)
    }

    /// Puts everything picked back on the Needed side.
    func moveBackToNeeded(_ item: ShoppingListItemDisplay) {
        setPickedQuantity(0, of: item)
    }
}
