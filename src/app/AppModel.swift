import Foundation
import RHKrogerAPI

/// Builds and owns everything the app needs at launch: the Kroger client,
/// the saved lists, and the store locator. `prepare()` is what the splash
/// screen waits on.
@MainActor
final class AppModel: ObservableObject {
    enum State {
        case launching
        case ready(Dependencies)
        case failed(String)
    }

    struct Dependencies {
        let client: KrogerClient
        let library: ShoppingListLibraryModel
        let locator: StoreLocator
    }

    @Published private(set) var state: State = .launching

    /// The longest the splash waits for the first store lookup. Past this the
    /// app opens anyway and the store row shows "Finding your store\u{2026}".
    private let storeLookupTimeout: Duration

    init(storeLookupTimeout: Duration = .seconds(3)) {
        self.storeLookupTimeout = storeLookupTimeout
    }

    var isReady: Bool {
        if case .launching = state { false } else { true }
    }

    /// Reads the configuration, loads the saved lists, and makes a first
    /// attempt at finding the store, then moves out of `.launching`.
    func prepare() async {
        guard case .launching = state else { return }
        do {
            let configuration = try AppConfiguration.fromBundle()
            let client = KrogerClient(
                tokenProvider: ClientCredentialsTokenProvider(
                    clientID: configuration.clientID, clientSecret: configuration.clientSecret
                )
            )
            let library = ShoppingListLibraryModel(store: try FileShoppingListStore.standard())
            let locator = StoreLocator(
                location: SystemLocationProvider(),
                search: KrogerStoreSearch(locations: client.locations)
            )
            await withTimeLimit(storeLookupTimeout) { await locator.refresh() }
            state = .ready(Dependencies(client: client, library: library, locator: locator))
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The app couldn\u{2019}t start.")
        }
    }

    /// Runs `work`, but stops waiting for it after `limit`. The work keeps
    /// going in the background if it's slow; only the wait is cut short.
    private func withTimeLimit(_ limit: Duration, _ work: @escaping @MainActor () async -> Void) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await work() }
            group.addTask { try? await Task.sleep(for: limit) }
            await group.next()
            group.cancelAll()
        }
    }
}
