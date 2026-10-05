import Foundation

/// Where the library is kept between launches.
///
/// A protocol so the rest of the app doesn't care how it's stored: this
/// first version is a JSON file, and it can become SwiftData or iCloud
/// later without touching the rules in `ShoppingListLibrary`.
protocol ShoppingListStoring: Sendable {
    /// The saved library, or nil on first launch.
    func load() throws -> ShoppingListLibrary?
    func save(_ library: ShoppingListLibrary) throws
}

/// Keeps the library in one JSON file, written atomically so a crash
/// mid-save can't leave a half-written file behind.
struct FileShoppingListStore: ShoppingListStoring {
    let url: URL

    /// The app's default location: `ShoppingLists.json` in Application Support.
    static func standard() throws -> FileShoppingListStore {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return FileShoppingListStore(url: directory.appending(path: "ShoppingLists.json"))
    }

    func load() throws -> ShoppingListLibrary? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Self.decoder.decode(ShoppingListLibrary.self, from: Data(contentsOf: url))
    }

    func save(_ library: ShoppingListLibrary) throws {
        try Self.encoder.encode(library).write(to: url, options: .atomic)
    }

    // Dates use the default encoding (exact seconds since 2001) rather than
    // ISO 8601, which drops fractions of a second and so wouldn't round-trip.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
}
