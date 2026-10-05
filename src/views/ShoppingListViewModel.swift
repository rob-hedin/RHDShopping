import Foundation
import RHKrogerAPI

/// Drives the shopping list screen.
///
/// Unlike the product picker, there's no network call and no "confirm" step
/// here: the products are already known (they came from the picker earlier),
/// and checking an item off takes effect immediately.
@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published private(set) var items: [ShoppingListItemDisplay]

    /// Builds the list from products already on hand (e.g. what the picker
    /// screen's `onAddSelected` handed back), optionally restoring which
    /// ones were already picked up.
    init(products: [KrogerProduct], pickedUpProductIDs: Set<String> = []) {
        items = Self.sorted(products.map { $0.asShoppingListItem(isPickedUp: pickedUpProductIDs.contains($0.id)) })
    }

    /// Seeds the list directly from display items. This is also what makes
    /// Previews possible: `KrogerProduct` has no public initializer, so a
    /// preview can't build the `products:` initializer's input.
    init(items: [ShoppingListItemDisplay]) {
        self.items = Self.sorted(items)
    }

    var pickedUpCount: Int { items.filter(\.isPickedUp).count }

    /// What's been spent so far: the effective price (promo if active,
    /// otherwise regular) of every picked-up item. Items with no known
    /// price contribute nothing, same as the "Price unavailable" fallback
    /// the row itself shows.
    var runningTotal: Decimal {
        items.filter(\.isPickedUp).reduce(Decimal(0)) { $0 + ($1.product.effectivePrice ?? 0) }
    }

    var runningTotalText: String { runningTotal.formatted(.currency(code: "USD")) }

    func togglePickedUp(_ item: ShoppingListItemDisplay) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPickedUp.toggle()
        // Picked-up items sink to the bottom, so a checked item doesn't sit
        // where it was — that's also why the row only dims instead of
        // striking the description through; it's about to move anyway.
        items = Self.sorted(items)
    }

    /// Not-picked-up items first, picked-up items last, each group keeping
    /// its original relative order.
    private static func sorted(_ items: [ShoppingListItemDisplay]) -> [ShoppingListItemDisplay] {
        items.filter { !$0.isPickedUp } + items.filter(\.isPickedUp)
    }
}
