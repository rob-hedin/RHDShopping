import Foundation

/// Works out which store to use and reports it as a `StoreStatus`.
///
/// Precedence: being in a store beats everything (you're shopping there),
/// then a store the person picked by hand, then the nearest store. The
/// answer is refreshed whenever `refresh()` is called, which the app does
/// on launch and each time it comes to the foreground.
@MainActor
final class StoreLocator: ObservableObject {
    @Published private(set) var status: StoreStatus
    /// The last place the device was found, so lists of stores can show distances.
    @Published private(set) var lastKnownPoint: GeoPoint?

    private let location: LocationProviding
    private let search: StoreSearching
    private let defaults: UserDefaults
    private static let chosenKey = "store.chosen"

    init(location: LocationProviding, search: StoreSearching, defaults: UserDefaults = .standard) {
        self.location = location
        self.search = search
        self.defaults = defaults
        status = Self.initialStatus(chosen: Self.loadChosen(from: defaults), authorization: location.authorization)
    }

    /// The store picked by hand, if any.
    var chosenStore: StoreRef? { Self.loadChosen(from: defaults) }

    /// Asks for location permission (once), then looks for a store.
    func requestPermission() async {
        _ = await location.requestAuthorization()
        await refresh()
    }

    /// Re-checks where the person is and updates `status`.
    func refresh() async {
        let chosen = chosenStore
        guard location.authorization == .authorized else {
            status = Self.initialStatus(chosen: chosen, authorization: location.authorization)
            return
        }
        // Don't flash "finding" over a store we already know.
        if status.store == nil { status = .locating }

        do {
            let point = try await location.currentLocation()
            lastKnownPoint = point
            let candidates = try await search.stores(near: point)
            if let match = StoreResolver.nearest(in: candidates, to: point) {
                if match.isInStore {
                    status = .inStore(match.store.ref)
                } else if let chosen {
                    status = .chosen(chosen)
                } else {
                    status = .nearest(match.store.ref)
                }
            } else {
                status = chosen.map(StoreStatus.chosen) ?? .unavailable
            }
        } catch {
            status = chosen.map(StoreStatus.chosen) ?? .unavailable
        }
    }

    /// The person picked a store by hand (for example from a ZIP code search).
    /// It's remembered. If they're physically in a different store, the next
    /// `refresh()` will notice and switch to that one.
    func choose(_ store: StoreRef) {
        if let data = try? JSONEncoder().encode(store) {
            defaults.set(data, forKey: Self.chosenKey)
        }
        status = .chosen(store)
    }

    /// Forgets the hand-picked store, going back to the nearest one.
    func clearChosenStore() async {
        defaults.removeObject(forKey: Self.chosenKey)
        await refresh()
    }

    private static func initialStatus(chosen: StoreRef?, authorization: LocationAuthorization) -> StoreStatus {
        if let chosen { return .chosen(chosen) }
        switch authorization {
        case .notDetermined: return .needsPermission
        case .denied: return .unavailable
        case .authorized: return .locating
        }
    }

    private static func loadChosen(from defaults: UserDefaults) -> StoreRef? {
        defaults.data(forKey: chosenKey).flatMap { try? JSONDecoder().decode(StoreRef.self, from: $0) }
    }
}
