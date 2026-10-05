import SwiftUI

/// Choose a store by ZIP code, or find the ones near the device. Presented
/// as a sheet; it owns its own Done button.
struct StorePickerView: View {
    @StateObject private var viewModel: StorePickerViewModel
    let selected: StoreRef?
    /// Nil hides "Near me" (no way to get the device's position).
    let onNearMe: (() async -> GeoPoint?)?
    let onSelect: (StoreRef) -> Void
    let onDone: () -> Void

    init(
        viewModel: @autoclosure @escaping () -> StorePickerViewModel,
        selected: StoreRef?,
        onNearMe: (() async -> GeoPoint?)?,
        onSelect: @escaping (StoreRef) -> Void,
        onDone: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.selected = selected
        self.onNearMe = onNearMe
        self.onSelect = onSelect
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                results
            }
            .navigationTitle("Choose a store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone).fontWeight(.semibold)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            TextField("ZIP code", text: $viewModel.zipCode)
                .keyboardType(.numberPad)
                .textContentType(.postalCode)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.searchByZIP() } }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                Task { await viewModel.searchByZIP() }
            } label: {
                Image(systemName: "magnifyingglass").frame(width: 44, height: 48)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canSearchZIP)
            .accessibilityLabel("Search")

            if let onNearMe {
                Button {
                    Task {
                        if let point = await onNearMe() { await viewModel.searchNear(point) }
                    }
                } label: {
                    Label("Near me", systemImage: "location.fill")
                        .labelStyle(.titleAndIcon)
                        .frame(minHeight: 48)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var results: some View {
        if viewModel.isSearching {
            ProgressView().frame(maxHeight: .infinity)
        } else if let message = viewModel.message, viewModel.rows.isEmpty {
            ContentUnavailableView(message, systemImage: "mappin.slash").frame(maxHeight: .infinity)
        } else if !viewModel.hasSearched {
            ContentUnavailableView(
                "Find your store",
                systemImage: "mappin.and.ellipse",
                description: Text("Enter a ZIP code, or use your current location.")
            )
            .frame(maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(viewModel.rows) { row in
                        Button { onSelect(row.ref) } label: { rowView(row) }
                            .buttonStyle(.plain)
                    }
                } header: {
                    Text(viewModel.rows.count == 1 ? "1 store" : "\(viewModel.rows.count) stores")
                }
            }
            .listStyle(.plain)
        }
    }

    private func rowView(_ row: StoreRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.ref.name).font(.headline)
                if let address = row.addressLine { Text(address).font(.footnote).foregroundStyle(.secondary) }
                if let detail = row.detailText { Text(detail).font(.footnote).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            if row.ref == selected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor).font(.title3)
                    .accessibilityLabel("Selected")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#if DEBUG
private struct PreviewStoreSearch: StoreSearching {
    func stores(near point: GeoPoint) async throws -> [StoreCandidate] { [] }
    func stores(zipCode: String) async throws -> [StoreCandidate] { [] }
}

@MainActor
private func previewPickerModel() -> StorePickerViewModel {
    StorePickerViewModel(search: PreviewStoreSearch(), userPoint: { nil })
}

#Preview("Store picker, empty") {
    StorePickerView(
        viewModel: previewPickerModel(), selected: nil,
        onNearMe: { nil }, onSelect: { _ in }, onDone: {}
    )
}
#endif
