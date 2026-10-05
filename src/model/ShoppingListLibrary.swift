import Foundation

/// The active shopping list plus the history of finished ones, and the
/// rules that move items between them.
///
/// A plain value type with no storage or UI of its own, so every rule here
/// is a function you can test with a few literals.
struct ShoppingListLibrary: Hashable, Codable {
    /// The list being built or shopped. There is always exactly one.
    var active: ShoppingList
    /// Finished lists, newest first.
    var history: [ShoppingList]

    init(active: ShoppingList = ShoppingList(), history: [ShoppingList] = []) {
        self.active = active
        self.history = history
    }

    // MARK: Finishing

    /// What finishing would carry to the next list, for the confirmation
    /// sheet. Empty means nothing is left over, so no confirmation is needed.
    var leftovers: [ShoppingListItemDisplay] {
        active.unpickedItems.map(Self.carriedOver)
    }

    /// Finishes the active list: it moves to the top of history, and a new
    /// active list starts holding whatever wasn't picked.
    ///
    /// Only the unpicked quantity carries (1 of 2 picked carries 1), items
    /// removed from the list are simply gone, and units picked beyond the
    /// request never carry. The finished list keeps its full record, so
    /// history still shows what wasn't picked.
    ///
    /// - Returns: How many items carried to the new list.
    @discardableResult
    mutating func finishActiveList(at date: Date = Date(), storeName: String? = nil) -> Int {
        let carried = leftovers

        var finished = active
        finished.completedAt = date
        finished.storeName = storeName ?? finished.storeName
        history.insert(finished, at: 0)

        active = ShoppingList(createdAt: date, items: carried)
        return carried.count
    }

    /// The same product as it should appear on a fresh list: the quantity
    /// still needed, nothing picked yet.
    private static func carriedOver(_ item: ShoppingListItemDisplay) -> ShoppingListItemDisplay {
        var copy = item
        copy.quantityRequested = item.quantityRemaining
        copy.quantityPicked = 0
        copy.stock = nil
        return copy
    }

    // MARK: Copying from history

    /// How copying items onto the active list would turn out.
    struct CopyOutcome: Hashable {
        /// Products not on the active list, added with their original quantity.
        var added: [ShoppingListItemDisplay]
        /// Products already on the active list. The active list's entry wins,
        /// so these are left exactly as they are.
        var unchanged: [ShoppingListItemDisplay]
    }

    /// What `copy(_:)` would do, without doing it (for the confirmation sheet).
    func previewCopy(_ items: [ShoppingListItemDisplay]) -> CopyOutcome {
        let existing = Set(active.items.map(\.id))
        var seen = existing
        var outcome = CopyOutcome(added: [], unchanged: [])
        for item in items {
            if existing.contains(item.id) {
                outcome.unchanged.append(item)
            } else if seen.insert(item.id).inserted {
                outcome.added.append(Self.copied(item))
            }
        }
        return outcome
    }

    /// Copies items (a whole past list, or a chosen few) onto the active
    /// list. A product missing from the active list is added with the
    /// quantity it was originally needed at; one already there is untouched.
    @discardableResult
    mutating func copy(_ items: [ShoppingListItemDisplay]) -> CopyOutcome {
        let outcome = previewCopy(items)
        active.items.append(contentsOf: outcome.added)
        return outcome
    }

    /// A past entry as a fresh, unpicked entry at its original quantity.
    private static func copied(_ item: ShoppingListItemDisplay) -> ShoppingListItemDisplay {
        var copy = item
        copy.quantityPicked = 0
        copy.stock = nil
        return copy
    }

    // MARK: Retention

    /// Drops finished lists completed more than `months` months before `date`.
    /// The active list is never touched.
    mutating func pruneHistory(keepingMonths months: Int, asOf date: Date = Date(), calendar: Calendar = .current) {
        guard let cutoff = calendar.date(byAdding: .month, value: -months, to: date) else { return }
        history.removeAll { ($0.completedAt ?? .distantFuture) < cutoff }
    }
}

/// How long finished lists are kept. The person's choice.
enum HistoryRetention {
    static let allowedMonths = [1, 3, 6, 12]
    static let defaultMonths = 3
    static let defaultsKey = "history.retentionMonths"

    /// The saved choice, falling back to the default for a missing or
    /// no-longer-offered value.
    static func months(in defaults: UserDefaults = .standard) -> Int {
        let saved = defaults.integer(forKey: defaultsKey)
        return allowedMonths.contains(saved) ? saved : defaultMonths
    }

    static func setMonths(_ months: Int, in defaults: UserDefaults = .standard) {
        guard allowedMonths.contains(months) else { return }
        defaults.set(months, forKey: defaultsKey)
    }
}
