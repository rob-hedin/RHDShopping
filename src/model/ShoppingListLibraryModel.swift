import Foundation

/// The app's single, observable source of truth for the active list and
/// history. It owns a `ShoppingListLibrary`, applies the person's retention
/// choice, and saves after every change.
///
/// Screens read `library` and call the methods here; they never save.
@MainActor
final class ShoppingListLibraryModel: ObservableObject {
    @Published private(set) var library: ShoppingListLibrary
    /// Set when the last load or save failed, for the UI to surface.
    @Published var errorMessage: String?

    private let store: ShoppingListStoring
    private let defaults: UserDefaults

    /// Loads the saved library (or starts a fresh one) and prunes history
    /// to the retention setting.
    init(store: ShoppingListStoring, defaults: UserDefaults = .standard, now: Date = Date()) {
        self.store = store
        self.defaults = defaults
        var loaded = ShoppingListLibrary()
        do {
            loaded = try store.load() ?? ShoppingListLibrary()
        } catch {
            // Keep going with an empty library rather than blocking launch.
            errorMessage = "Couldn't load your saved lists."
        }
        loaded.pruneHistory(keepingMonths: HistoryRetention.months(in: defaults), asOf: now)
        library = loaded
    }

    var active: ShoppingList { library.active }
    var history: [ShoppingList] { library.history }

    /// Items that would move to the next list; empty means finishing needs
    /// no confirmation.
    var leftovers: [ShoppingListItemDisplay] { library.leftovers }

    /// Applies an edit to the active list's items and saves.
    func updateActiveItems(_ edit: (inout [ShoppingListItemDisplay]) -> Void) {
        apply { edit(&$0.active.items) }
    }

    @discardableResult
    func finishActiveList(storeName: String? = nil, at date: Date = Date()) -> Int {
        var carried = 0
        apply { carried = $0.finishActiveList(at: date, storeName: storeName) }
        return carried
    }

    func previewCopy(_ items: [ShoppingListItemDisplay]) -> ShoppingListLibrary.CopyOutcome {
        library.previewCopy(items)
    }

    @discardableResult
    func copyToActiveList(_ items: [ShoppingListItemDisplay]) -> ShoppingListLibrary.CopyOutcome {
        var outcome = ShoppingListLibrary.CopyOutcome(added: [], unchanged: [])
        apply { outcome = $0.copy(items) }
        return outcome
    }

    /// Saves a new retention choice and prunes immediately.
    func setRetentionMonths(_ months: Int, now: Date = Date()) {
        HistoryRetention.setMonths(months, in: defaults)
        apply { $0.pruneHistory(keepingMonths: HistoryRetention.months(in: defaults), asOf: now) }
    }

    private func apply(_ change: (inout ShoppingListLibrary) -> Void) {
        var updated = library
        change(&updated)
        library = updated
        do {
            try store.save(updated)
        } catch {
            errorMessage = "Couldn't save your lists."
        }
    }
}
