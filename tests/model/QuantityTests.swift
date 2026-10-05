// Unit tests for choosing a quantity when adding products. They use Swift Testing.
import Foundation
import RHKrogerAPI
import Testing
@testable import RHDShopping

private struct NoSearch: ProductSearching {
    func search(
        term: String?, locationID: String?, productIDs: [String], brands: [String],
        fulfillment: Set<KrogerFulfillment>, start: Int?, limit: Int?
    ) async throws -> [KrogerProduct] { [] }
}

private func row(_ id: String) -> ProductDisplayItem {
    ProductDisplayItem(id: id, brand: nil, description: "Item \(id)", category: nil, imageURL: nil,
                       regularPrice: 1, promoPrice: nil, pricePerUnit: nil)
}

@MainActor @Suite struct PickerQuantityTests {
    private func model(_ ids: String...) -> ProductListViewModel {
        ProductListViewModel(searchTerm: "milk", locationID: "01400943", products: NoSearch(), initialItems: ids.map(row))
    }

    @Test func checkingARowStartsAtOneAndUncheckingForgetsIt() {
        let vm = model("a")
        vm.toggleSelection(row("a"))
        #expect(vm.isSelected(row("a")) && vm.quantity(for: row("a")) == 1)
        vm.setQuantity(4, for: row("a"))
        #expect(vm.quantity(for: row("a")) == 4)
        vm.toggleSelection(row("a"))
        #expect(!vm.isSelected(row("a")))
        vm.toggleSelection(row("a"))                       // checked again: back to 1, not the old 4
        #expect(vm.quantity(for: row("a")) == 1)
    }

    @Test func quantityIsClampedAndIgnoredForUncheckedRows() {
        let vm = model("a", "b")
        vm.toggleSelection(row("a"))
        vm.setQuantity(0, for: row("a")); #expect(vm.quantity(for: row("a")) == 1)
        vm.setQuantity(500, for: row("a")); #expect(vm.quantity(for: row("a")) == 99)
        vm.setQuantity(5, for: row("b")); #expect(!vm.isSelected(row("b")) && vm.quantity(for: row("b")) == 1)
    }

    @Test func unitCountSumsQuantitiesAcrossCheckedRows() {
        let vm = model("a", "b", "c")
        vm.toggleSelection(row("a")); vm.toggleSelection(row("b"))
        vm.setQuantity(2, for: row("a")); vm.setQuantity(3, for: row("b"))
        #expect(vm.selectedCount == 2 && vm.selectedUnitCount == 5)
    }

    @Test func selectFromTheDetailScreenSetsTheQuantityAndIsRepeatable() {
        let vm = model("a")
        vm.select(row("a"), quantity: 3)
        vm.select(row("a"), quantity: 2)                   // second add replaces, doesn't stack or toggle off
        #expect(vm.isSelected(row("a")) && vm.quantity(for: row("a")) == 2)
        vm.select(row("a"), quantity: 0)
        #expect(vm.quantity(for: row("a")) == 1)
    }
}

@MainActor @Suite struct ListAddTests {
    private func entry(_ id: String, requested: Int = 1, picked: Int = 0) -> ShoppingListItemDisplay {
        ShoppingListItemDisplay(id: id, product: row(id), aisle: nil, quantityRequested: requested, quantityPicked: picked)
    }
    private func defaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "ListAddTests")!; d.removePersistentDomain(forName: "ListAddTests"); return d
    }

    @Test func newProductsAreAddedAtTheirQuantity() {
        let vm = ShoppingListViewModel(items: [], mode: .planning, defaults: defaults())
        vm.add(items: [entry("a", requested: 3), entry("b", requested: 1)])
        #expect(vm.items.map(\.id) == ["a", "b"])
        #expect(vm.items.map(\.quantityRequested) == [3, 1])
    }

    @Test func aProductAlreadyOnTheListHasTheNewQuantityAddedAndPickedUntouched() {
        let vm = ShoppingListViewModel(items: [entry("a", requested: 2, picked: 1)], mode: .planning, defaults: defaults())
        vm.add(items: [entry("a", requested: 2)])
        #expect(vm.items.count == 1)
        #expect(vm.items[0].quantityRequested == 4 && vm.items[0].quantityPicked == 1)
        #expect(vm.items[0].quantityRemaining == 3)
    }

    @Test func addingToAFullyPickedProductPutsTheNewAmountBackInNeeded() {
        let vm = ShoppingListViewModel(items: [entry("a", requested: 1, picked: 1)], mode: .inStore, defaults: defaults())
        #expect(vm.items(in: .needed).isEmpty)
        vm.add(items: [entry("a", requested: 2)])
        #expect(vm.items(in: .needed).first?.quantity(in: .needed) == 2)
    }

    @Test func duplicatesWithinOneAddCombine() {
        let vm = ShoppingListViewModel(items: [], mode: .planning, defaults: defaults())
        vm.add(items: [entry("a", requested: 1), entry("a", requested: 2)])
        #expect(vm.items.count == 1 && vm.items[0].quantityRequested == 3)
    }
}
