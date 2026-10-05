import SwiftUI

/// The first screen after launch: which store, a search field, recent
/// searches, and a card that leads to the shopping list (plus History).
///
/// It reacts to a `StoreStatus` it's handed rather than working out the
/// store itself, so detecting the nearest store or being in one is somebody
/// else's job. Search is held back until there's a store, because prices and
/// stock come from one.
struct MainView: View {
    @ObservedObject var list: ShoppingListViewModel
    let status: StoreStatus
    let recents: [String]
    let onSearch: (String) -> Void
    let onOpenList: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onChooseStore: () -> Void
    let onRequestLocation: () -> Void

    @State private var term = ""
    @FocusState private var isSearching: Bool

    /// The Products API needs at least three characters.
    private static let minimumTermLength = 3

    private var canSearch: Bool { status.store != nil }
    private var trimmedTerm: String { term.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
            Text("What do you need?")
                .font(.largeTitle.bold())
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            searchField
            if showsLocationPrompt { locationPrompt }
            if canSearch, !recents.isEmpty { recentSearches }
            Spacer(minLength: 16)
            listCard
            historyRow
        }
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    // MARK: Top row

    private var topRow: some View {
        HStack {
            Button(action: onChooseStore) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(storeCaption.text).font(.caption.weight(.semibold)).foregroundStyle(storeCaption.color)
                        Text(storeTitle).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    }
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape").font(.title3).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 20)
    }

    private var storeTitle: String {
        status.store?.name ?? "Choose a store"
    }

    private var storeCaption: (text: String, color: Color) {
        switch status {
        case .inStore: ("\u{25CF} You\u{2019}re here", .green)
        case .nearest: ("Nearest to you", .secondary)
        case .chosen: ("Your store", .secondary)
        case .locating: ("Finding your store\u{2026}", .secondary)
        case .needsPermission, .unavailable: ("No store yet", .secondary)
        }
    }

    // MARK: Search

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search products", text: $term)
                    .focused($isSearching)
                    .submitLabel(.search)
                    .onSubmit(submit)
                    .disabled(!canSearch)
                if !term.isEmpty {
                    Button { term = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.leading, 16)
            .frame(minHeight: 52)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if isSearching, !trimmedTerm.isEmpty, trimmedTerm.count < Self.minimumTermLength {
                Text("Type at least \(Self.minimumTermLength) characters.").font(.footnote).foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 20)
    }

    private func submit() {
        guard canSearch, trimmedTerm.count >= Self.minimumTermLength else { return }
        onSearch(trimmedTerm)
        term = ""
    }

    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT SEARCHES").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).tracking(0.5)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recents, id: \.self) { recent in
                        Button(recent) { onSearch(recent) }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 24)
    }

    // MARK: Location prompt

    private var showsLocationPrompt: Bool {
        switch status {
        case .needsPermission, .unavailable: true
        default: false
        }
    }

    private var locationPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("**Find your store automatically.** Allow location access and we\u{2019}ll use the nearest store for prices, aisles and stock. Your location stays on your device.")
                .font(.subheadline)
            HStack(spacing: 10) {
                if status == .needsPermission {
                    Button(action: onRequestLocation) {
                        Text("Allow Location").frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button(action: onChooseStore) {
                    Text("Enter ZIP Code").frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: List card

    private var listCard: some View {
        let needed = list.items(in: .needed)
        let picked = list.items(in: .picked)
        return Button(action: onOpenList) {
            if list.items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your list is empty").font(.headline)
                    Text("Search for a product to add it to your shopping list.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Shopping list").font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(list.totalText(for: .needed)).font(.system(size: 34, weight: .bold))
                        Spacer()
                        Text(list.mode == .inStore ? "to spend" : "estimated").font(.subheadline)
                    }
                    if list.mode == .inStore, !picked.isEmpty {
                        ProgressView(value: Double(picked.count), total: Double(picked.count + needed.count))
                            .tint(.white)
                    }
                    Text(cardDetail(needed: needed.count, picked: picked.count)).font(.footnote)
                }
                .foregroundStyle(.white)
                .padding(18)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func cardDetail(needed: Int, picked: Int) -> String {
        if list.mode == .inStore {
            return "\(needed) needed \u{B7} \(picked) picked \u{B7} \(list.totalText(for: .picked)) spent"
        }
        let items = list.items.count == 1 ? "1 item" : "\(list.items.count) items"
        return [items, status.store.map { "prices from \($0.name)" }].compactMap { $0 }.joined(separator: " \u{B7} ")
    }

    private var historyRow: some View {
        Button(action: onOpenHistory) {
            HStack {
                Text("History")
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }
}

#if DEBUG
private let previewStore = StoreRef(id: "01400943", name: "Main St")

@MainActor private func previewList(_ mode: ShoppingMode, picked: Bool) -> ShoppingListViewModel {
    func item(_ id: String, _ name: String, _ price: Decimal, picked: Int = 0) -> ShoppingListItemDisplay {
        ShoppingListItemDisplay(
            id: id,
            product: ProductDisplayItem(id: id, brand: nil, description: name, category: nil, imageURL: nil, regularPrice: price, promoPrice: nil, pricePerUnit: nil),
            aisle: nil, quantityPicked: picked
        )
    }
    let suite = "MainViewPreview"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return ShoppingListViewModel(
        items: [item("1", "Organic Whole Milk", 4.49), item("2", "Lactose-Free Milk", 4.99), item("3", "Salted Butter", 4.29, picked: picked ? 1 : 0)],
        mode: mode, defaults: defaults
    )
}

@MainActor private func mainPreview(_ status: StoreStatus, list: ShoppingListViewModel, recents: [String] = ["milk", "eggs", "bread"]) -> some View {
    MainView(
        list: list, status: status, recents: recents,
        onSearch: { _ in }, onOpenList: {}, onOpenHistory: {}, onOpenSettings: {},
        onChooseStore: {}, onRequestLocation: {}
    )
}

#Preview("At home") { mainPreview(.nearest(previewStore), list: previewList(.planning, picked: false)) }
#Preview("In store") { mainPreview(.inStore(previewStore), list: previewList(.inStore, picked: true)) }
#Preview("First launch") { mainPreview(.needsPermission, list: previewList(.planning, picked: false).emptied(), recents: []) }

@MainActor
private extension ShoppingListViewModel {
    func emptied() -> ShoppingListViewModel {
        ShoppingListViewModel(items: [], mode: mode, defaults: UserDefaults(suiteName: "MainViewPreviewEmpty")!)
    }
}
#endif
