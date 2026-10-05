import Foundation

/// The terms the person searched for lately, newest first, for the main
/// screen's quick-search chips. Kept on the device in `UserDefaults`.
struct RecentSearches {
    static let defaultsKey = "search.recentTerms"
    static let limit = 8

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var terms: [String] {
        defaults.stringArray(forKey: Self.defaultsKey) ?? []
    }

    /// Records a search. Repeats (ignoring case) move to the front instead of
    /// duplicating, and only the newest `limit` are kept.
    func record(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = terms.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        updated.insert(trimmed, at: 0)
        defaults.set(Array(updated.prefix(Self.limit)), forKey: Self.defaultsKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
