import Foundation

/// A store that keeps the library in memory only, for Previews and tests.
final class InMemoryShoppingListStore: ShoppingListStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var library: ShoppingListLibrary?

    init(_ library: ShoppingListLibrary? = nil) {
        self.library = library
    }

    func load() throws -> ShoppingListLibrary? {
        lock.withLock { library }
    }

    func save(_ library: ShoppingListLibrary) throws {
        lock.withLock { self.library = library }
    }
}
