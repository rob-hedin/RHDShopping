import SwiftUI

/// App settings. For now just how long finished lists are kept; changing it
/// prunes older lists straight away.
struct SettingsView: View {
    @ObservedObject var library: ShoppingListLibraryModel
    @State private var months = HistoryRetention.months()

    var body: some View {
        Form {
            Section {
                ForEach(HistoryRetention.allowedMonths, id: \.self) { option in
                    Button {
                        months = option
                        library.setRetentionMonths(option)
                    } label: {
                        HStack {
                            Text(option == 1 ? "1 month" : "\(option) months")
                            Spacer()
                            if option == months {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == months ? .isSelected : [])
                }
            } header: {
                Text("Keep history for")
            } footer: {
                Text("Finished lists older than this are removed automatically. Lists you\u{2019}re still shopping are never removed.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Settings") {
    NavigationStack {
        SettingsView(library: ShoppingListLibraryModel(store: InMemoryShoppingListStore()))
    }
}
#endif
