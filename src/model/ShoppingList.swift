import Foundation

/// One shopping list: the active one the person is building or shopping,
/// or a finished one kept in history.
///
/// Items are snapshots (`ShoppingListItemDisplay` holds the name, price and
/// aisle as they were), so a finished list reads the same years later no
/// matter what the Kroger API says about those products now.
struct ShoppingList: Identifiable, Hashable, Codable {
    let id: UUID
    let createdAt: Date
    /// Nil while the list is still active.
    var completedAt: Date?
    /// The store the list was finished at, when one was known.
    var storeName: String?
    var items: [ShoppingListItemDisplay]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        storeName: String? = nil,
        items: [ShoppingListItemDisplay] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.storeName = storeName
        self.items = items
    }

    var isActive: Bool { completedAt == nil }

    /// Everything actually picked, at the price in effect when it was picked
    /// (including any units beyond what was requested).
    var totalSpent: Decimal {
        items.reduce(Decimal(0)) { $0 + $1.total(in: .picked) }
    }

    /// Items with at least one unit still not picked.
    var unpickedItems: [ShoppingListItemDisplay] {
        items.filter { $0.quantityRemaining > 0 }
    }

    var pickedItemCount: Int { items.filter { $0.quantityPicked > 0 }.count }
}
