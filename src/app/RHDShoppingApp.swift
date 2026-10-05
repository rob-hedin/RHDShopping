import SwiftUI

@main
struct RHDShoppingApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            LaunchGate(isReady: model.isReady) {
                switch model.state {
                case .ready(let dependencies):
                    RootView(client: dependencies.client, library: dependencies.library, locator: dependencies.locator)
                case .failed(let message):
                    ContentUnavailableView(
                        "Couldn\u{2019}t start",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                case .launching:
                    EmptyView()
                }
            }
            .task { await model.prepare() }
            .onChange(of: scenePhase) { _, phase in
                // Re-check the store each time the app comes back to the front,
                // so walking into a store switches the list to in-store mode.
                guard phase == .active, case .ready(let dependencies) = model.state else { return }
                Task { await dependencies.locator.refresh() }
            }
        }
    }
}
