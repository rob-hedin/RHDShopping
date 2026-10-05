// Unit tests for the app's model, location and refresh logic. They use Swift Testing.
import Foundation
import Testing
@testable import RHDShopping

private func id13(_ n: Int) -> String { String(format: "%013d", n) }

private func item(_ id: String, price: String, aisle: String? = nil, stock: ProductDetailDisplay.Stock? = nil,
                  requested: Int = 1, picked: Int = 0) -> ShoppingListItemDisplay {
    ShoppingListItemDisplay(
        id: id,
        product: ProductDisplayItem(id: id, brand: "B", description: "Item \(id.suffix(2))", category: nil, imageURL: nil,
                                    regularPrice: Decimal(string: price)!, promoPrice: nil, pricePerUnit: nil),
        aisle: aisle.map { AisleLocationDisplay(description: $0, side: nil, shelfNumber: nil) },
        quantityRequested: requested, quantityPicked: picked, stock: stock)
}

private actor Calls {
    var batches: [[String]] = []
    func record(_ ids: [String]) { batches.append(ids) }
}

@Suite struct RefresherTests {
    @Test func fetchesInBatchesOfFiftyAndReportsMissing() async throws {
        let calls = Calls()
        let ids = (1...120).map(id13)
        let refresher = StoreDataRefresher { batch, store in
            await calls.record(batch)
            #expect(store == "01400943")
            return batch.filter { $0 != id13(7) && $0 != id13(99) }.map { item($0, price: "1.00") }
        }
        let result = try await refresher.refresh(productIDs: ids, storeID: "01400943")
        #expect(await calls.batches.map(\.count) == [50, 50, 20])
        #expect(result.fresh.count == 118)
        #expect(Set(result.missingIDs) == [id13(7), id13(99)])
    }

    @Test func idsOfTheWrongLengthAreSkippedNotMissing() async throws {
        let calls = Calls()
        let refresher = StoreDataRefresher { batch, _ in await calls.record(batch); return batch.map { item($0, price: "1.00") } }
        let result = try await refresher.refresh(productIDs: [id13(1), "123", "not-an-id"], storeID: "01400943")
        #expect(await calls.batches == [[id13(1)]])
        #expect(result.missingIDs.isEmpty)
    }

    @Test func aFailureThrowsAndNoRequestIsMadeForNothing() async {
        let calls = Calls()
        let ok = StoreDataRefresher { _, _ in await calls.record([]); return [] }
        _ = try? await ok.refresh(productIDs: [], storeID: "01400943")
        #expect(await calls.batches.isEmpty)
        let bad = StoreDataRefresher { _, _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: URLError.self) { try await bad.refresh(productIDs: [id13(1)], storeID: "x") }
    }

    @Test func refreshedKeepsQuantitiesAndFreezesPickedPrices() {
        let fresh = item(id13(1), price: "5.00", aisle: "Aisle 9", stock: .lowStock)
        let unpicked = item(id13(1), price: "4.00", requested: 3).refreshed(from: fresh)
        #expect(unpicked.product.regularPrice == Decimal(string: "5.00"))
        #expect(unpicked.aisle?.description == "Aisle 9")
        #expect(unpicked.stock == .lowStock)
        #expect(unpicked.quantityRequested == 3 && unpicked.quantityPicked == 0)

        let picked = item(id13(1), price: "4.00", requested: 3, picked: 1).refreshed(from: fresh)
        #expect(picked.product.regularPrice == Decimal(string: "4.00"))      // what was paid stays
        #expect(picked.aisle?.description == "Aisle 9")                      // location still updates
        #expect(picked.quantityRequested == 3 && picked.quantityPicked == 1)
    }
}

@MainActor @Suite struct ViewModelRefreshTests {
    func defaults(_ n: String) -> UserDefaults { let d = UserDefaults(suiteName: n)!; d.removePersistentDomain(forName: n); return d }
    let store = StoreRef(id: "01400943", name: "Main St")

    @Test func updatesPriceAisleAndStockAndNotesWhatTheStoreDoesntCarry() async {
        let vm = ShoppingListViewModel(items: [
            item(id13(1), price: "4.00", requested: 2), item(id13(2), price: "3.00"), item(id13(3), price: "9.00"),
        ], mode: .inStore, defaults: defaults("R1"))
        let refresher = StoreDataRefresher { ids, _ in
            ids.filter { $0 != id13(3) }.map { item($0, price: $0 == id13(1) ? "4.50" : "2.50", aisle: "Aisle 4", stock: $0 == id13(2) ? .outOfStock : .inStock) }
        }
        await vm.refresh(for: store, using: refresher)

        let a = vm.items.first { $0.id == id13(1) }!, b = vm.items.first { $0.id == id13(2) }!, c = vm.items.first { $0.id == id13(3) }!
        #expect(a.product.regularPrice == Decimal(string: "4.50") && a.quantityRequested == 2)
        #expect(a.aisle?.description == "Aisle 4" && a.stock == .inStock)
        #expect(b.isOutOfStock)
        #expect(c.product.regularPrice == Decimal(string: "9.00"))           // not carried: left as it was
        #expect(vm.storeNotice == "1 item isn\u{2019}t sold at Main St.")
        #expect(!vm.isRefreshing)
        vm.dismissStoreNotice(); #expect(vm.storeNotice == nil)
    }

    @Test func aFailureLeavesTheListAlone() async {
        let vm = ShoppingListViewModel(items: [item(id13(1), price: "4.00")], mode: .inStore, defaults: defaults("R2"))
        await vm.refresh(for: store, using: StoreDataRefresher { _, _ in throw URLError(.timedOut) })
        #expect(vm.items[0].product.regularPrice == Decimal(string: "4.00"))
        #expect(vm.storeNotice == nil && !vm.isRefreshing)
    }

    @Test func emptyListDoesNothingAndClearsTheNotice() async {
        let vm = ShoppingListViewModel(items: [], mode: .inStore, defaults: defaults("R3"))
        await vm.refresh(for: store, using: StoreDataRefresher { _, _ in Issue.record("should not fetch"); return [] })
        #expect(vm.storeNotice == nil)
    }

    @Test func aNewerRefreshWinsOverASlowOlderOne() async {
        let vm = ShoppingListViewModel(items: [item(id13(1), price: "4.00")], mode: .inStore, defaults: defaults("R4"))
        let slow = StoreDataRefresher { ids, _ in try await Task.sleep(for: .milliseconds(300)); return ids.map { item($0, price: "OLD".isEmpty ? "0" : "7.00") } }
        let quick = StoreDataRefresher { ids, _ in ids.map { item($0, price: "5.00") } }
        let older = Task { await vm.refresh(for: store, using: slow) }
        try? await Task.sleep(for: .milliseconds(50))
        await vm.refresh(for: StoreRef(id: "01400441", name: "Oak Ave"), using: quick)
        await older.value
        #expect(vm.items[0].product.regularPrice == Decimal(string: "5.00"))   // the slow one didn't overwrite
        #expect(!vm.isRefreshing)
    }
}
