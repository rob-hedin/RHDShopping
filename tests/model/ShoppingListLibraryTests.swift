// Unit tests for the app's model, location and refresh logic. They use Swift Testing.
import Foundation
import Testing
@testable import RHDShopping

private func dec(_ s: String) -> Decimal { Decimal(string: s)! }

private func entry(_ id: String, requested: Int = 1, picked: Int = 0, price: String = "1.00") -> ShoppingListItemDisplay {
    ShoppingListItemDisplay(
        id: id,
        product: ProductDisplayItem(id: id, brand: "B", description: "Item \(id)", category: nil, imageURL: nil,
                                    regularPrice: dec(price), promoPrice: nil, pricePerUnit: nil),
        aisle: AisleLocationDisplay(description: "Dairy", side: "Left", shelfNumber: "3"),
        quantityRequested: requested, quantityPicked: picked, stock: .lowStock)
}

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}

@Suite struct FinishTests {
    @Test func carriesOnlyTheUnpickedQuantity() {
        var lib = ShoppingListLibrary(active: ShoppingList(items: [
            entry("a", requested: 2, picked: 1),   // 1 left
            entry("b", requested: 1, picked: 1),   // done
            entry("c", requested: 3, picked: 0),   // all left
            entry("d", requested: 1, picked: 4),   // over-picked
        ]))
        let carried = lib.finishActiveList(at: date(2026, 10, 5), storeName: "Store")
        #expect(carried == 2)
        #expect(lib.active.items.map(\.id) == ["a", "c"])
        #expect(lib.active.items.map(\.quantityRequested) == [1, 3])
        #expect(lib.active.items.allSatisfy { $0.quantityPicked == 0 && $0.stock == nil })
        #expect(lib.active.completedAt == nil)
    }

    @Test func finishedListKeepsItsFullRecordNewestFirst() {
        var lib = ShoppingListLibrary(active: ShoppingList(items: [entry("a", requested: 2, picked: 1, price: "4.49")]))
        lib.finishActiveList(at: date(2026, 9, 1), storeName: "S1")
        lib.active.items[0].quantityPicked = 1
        lib.finishActiveList(at: date(2026, 9, 8), storeName: "S2")
        #expect(lib.history.map(\.storeName) == ["S2", "S1"])
        #expect(lib.history[1].items[0].quantityRequested == 2)
        #expect(lib.history[1].items[0].quantityPicked == 1)
        #expect(lib.history[1].totalSpent == dec("4.49"))
        #expect(lib.history[1].completedAt == date(2026, 9, 1))
    }

    @Test func leftoversMatchWhatFinishCarries() {
        var lib = ShoppingListLibrary(active: ShoppingList(items: [entry("a", requested: 2, picked: 1), entry("b", picked: 1)]))
        let preview = lib.leftovers
        lib.finishActiveList()
        #expect(preview == lib.active.items)
    }

    @Test func nothingLeftoverMeansEmptyNewList() {
        var lib = ShoppingListLibrary(active: ShoppingList(items: [entry("a", picked: 1)]))
        #expect(lib.leftovers.isEmpty)
        #expect(lib.finishActiveList() == 0)
        #expect(lib.active.items.isEmpty)
        #expect(lib.history.count == 1)
    }
}

@Suite struct CopyTests {
    @Test func newProductsAddedAtOriginalQuantityExistingUntouched() {
        var lib = ShoppingListLibrary(active: ShoppingList(items: [entry("almond", requested: 1)]))
        let past = [entry("milk", requested: 1, picked: 1), entry("butter", requested: 2, picked: 2), entry("almond", requested: 5, picked: 0)]
        let outcome = lib.copy(past)
        #expect(outcome.added.map(\.id) == ["milk", "butter"])
        #expect(outcome.unchanged.map(\.id) == ["almond"])
        #expect(lib.active.items.map(\.id) == ["almond", "milk", "butter"])
        #expect(lib.active.items.first { $0.id == "almond" }?.quantityRequested == 1)   // active wins
        #expect(lib.active.items.first { $0.id == "butter" }?.quantityRequested == 2)   // original need
        #expect(lib.active.items.first { $0.id == "butter" }?.quantityPicked == 0)      // fresh
    }

    @Test func previewMatchesCopyAndDoesNotMutate() {
        var lib = ShoppingListLibrary(active: ShoppingList(items: [entry("a")]))
        let items = [entry("a"), entry("b")]
        let before = lib
        let preview = lib.previewCopy(items)
        #expect(lib == before)
        #expect(lib.copy(items) == preview)
    }

    @Test func duplicateInputsAddOnce() {
        var lib = ShoppingListLibrary()
        lib.copy([entry("a"), entry("a")])
        #expect(lib.active.items.count == 1)
    }
}

@Suite struct RetentionTests {
    @Test func prunesOnlyFinishedListsOlderThanTheWindow() {
        let old = ShoppingList(createdAt: date(2026, 5, 1), completedAt: date(2026, 5, 1))
        let edge = ShoppingList(createdAt: date(2026, 7, 6), completedAt: date(2026, 7, 6))
        let recent = ShoppingList(createdAt: date(2026, 9, 21), completedAt: date(2026, 9, 21))
        var lib = ShoppingListLibrary(active: ShoppingList(createdAt: date(2026, 1, 1)), history: [recent, edge, old])
        lib.pruneHistory(keepingMonths: 3, asOf: date(2026, 10, 5), calendar: Calendar(identifier: .gregorian))
        #expect(lib.history == [recent, edge].filter { _ in true })   // 3 months back = Jul 5; Jul 6 stays
        #expect(lib.active.createdAt == date(2026, 1, 1))              // active never pruned
    }

    @Test func settingFallsBackToDefaultAndRejectsUnofferedValues() {
        let defaults = UserDefaults(suiteName: "RetentionTests")!
        defaults.removePersistentDomain(forName: "RetentionTests")
        #expect(HistoryRetention.months(in: defaults) == 3)
        HistoryRetention.setMonths(6, in: defaults)
        #expect(HistoryRetention.months(in: defaults) == 6)
        HistoryRetention.setMonths(5, in: defaults)
        #expect(HistoryRetention.months(in: defaults) == 6)
        defaults.removePersistentDomain(forName: "RetentionTests")
    }
}

@Suite struct StoreTests {
    @Test func roundTripsThroughAFileWithoutStock() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "lib-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FileShoppingListStore(url: url)
        #expect(try store.load() == nil)

        var lib = ShoppingListLibrary(active: ShoppingList(items: [entry("a", requested: 2, picked: 1, price: "4.49")]))
        lib.finishActiveList(at: date(2026, 9, 21), storeName: "Store")
        try store.save(lib)

        let loaded = try #require(try store.load())
        var expected = lib.history
        for l in expected.indices { for i in expected[l].items.indices { expected[l].items[i].stock = nil } }
        #expect(loaded.history == expected)                     // identical except live stock
        #expect(loaded.active.items.map(\.id) == lib.active.items.map(\.id))
        #expect(loaded.history[0].items[0].product.regularPrice == dec("4.49"))
        #expect(loaded.history[0].items[0].stock == nil)        // live info isn't saved
    }
}

@MainActor @Suite struct ModelTests {
    final class MemoryStore: ShoppingListStoring, @unchecked Sendable {
        var saved: ShoppingListLibrary?
        func load() throws -> ShoppingListLibrary? { saved }
        func save(_ library: ShoppingListLibrary) throws { saved = library }
    }

    @Test func savesAfterEveryChangeAndPrunesOnLaunchAndOnSettingChange() {
        let defaults = UserDefaults(suiteName: "ModelTests")!
        defaults.removePersistentDomain(forName: "ModelTests")
        let store = MemoryStore()
        store.saved = ShoppingListLibrary(
            active: ShoppingList(items: [entry("a", requested: 2, picked: 1)]),
            history: [ShoppingList(createdAt: date(2026, 5, 1), completedAt: date(2026, 5, 1)),
                      ShoppingList(createdAt: date(2026, 8, 20), completedAt: date(2026, 8, 20))])
        let model = ShoppingListLibraryModel(store: store, defaults: defaults, now: date(2026, 10, 5))
        #expect(model.history.count == 1)                       // May list pruned at 3 months

        #expect(model.finishActiveList(storeName: "S", at: date(2026, 10, 5)) == 1)
        #expect(store.saved?.history.count == 2)
        #expect(store.saved?.active.items.map(\.quantityRequested) == [1])

        model.setRetentionMonths(1, now: date(2026, 10, 5))
        #expect(model.history.count == 1)                       // only Oct 5 left
        #expect(store.saved?.history.count == 1)
        defaults.removePersistentDomain(forName: "ModelTests")
    }
}

@Suite struct RecentSearchTests {
    @Test func newestFirstDedupedIgnoringCaseAndCapped() {
        let d = UserDefaults(suiteName: "RecentTests")!
        d.removePersistentDomain(forName: "RecentTests")
        let r = RecentSearches(defaults: d)
        r.record("milk"); r.record("eggs"); r.record("  Milk  "); r.record("   ")
        #expect(r.terms == ["Milk", "eggs"])
        for i in 0..<20 { r.record("t\(i)") }
        #expect(r.terms.count == RecentSearches.limit)
        #expect(r.terms.first == "t19")
        r.clear(); #expect(r.terms.isEmpty)
        d.removePersistentDomain(forName: "RecentTests")
    }
}

@Suite struct StoreStatusTests {
    @Test func storeAndInStoreFollowTheCase() {
        let s = StoreRef(id: "01400943", name: "Main St")
        #expect(StoreStatus.inStore(s).isInStore)
        #expect(!StoreStatus.nearest(s).isInStore)
        #expect(StoreStatus.chosen(s).store == s)
        #expect(StoreStatus.needsPermission.store == nil)
        #expect(StoreStatus.locating.store == nil)
    }
}
