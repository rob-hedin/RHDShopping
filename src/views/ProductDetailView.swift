import SwiftUI
import RHKrogerAPI

/// Everything known about one product at the person's store. Meant to be
/// pushed from the product picker, so unlike `ProductListView` it relies on
/// the surrounding `NavigationStack` for its back button.
///
/// `onAddToList` hands back the full `KrogerProduct`, like the picker's
/// `onAddSelected`; there's no cart or quantity here. Pass nil (a product
/// already on the list, say) to hide the Add to List button.
struct ProductDetailView: View {
    @StateObject private var viewModel: ProductDetailViewModel
    let onAddToList: ((KrogerProduct) -> Void)?

    init(
        viewModel: @autoclosure @escaping () -> ProductDetailViewModel,
        onAddToList: ((KrogerProduct) -> Void)?
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onAddToList = onAddToList
    }

    var body: some View {
        Group {
            if let detail = viewModel.detail {
                content(detail)
            } else if viewModel.isLoading {
                ProgressView()
            } else {
                ContentUnavailableView {
                    Label("Couldn't load product", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("Try Again") { Task { await viewModel.load() } }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .alert("Something went wrong", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.errorMessage = nil }
            }
        )
    }

    private func content(_ detail: ProductDetailDisplay) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ImageCarousel(urls: detail.imageURLs)
                header(detail)
                priceCard(detail)
                if !detail.fulfillment.isEmpty { fulfillmentSection(detail) }
                if let aisle = detail.aisleText { aisleRow(aisle) }
                if !detail.badges.isEmpty { badgeRow(detail.badges) }
                if let allergens = detail.allergensText { allergenCard(allergens) }
                if !detail.nutrition.isEmpty { nutritionCard(detail) }
                if let ingredients = detail.ingredients {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingredients").font(.headline)
                        Text(ingredients).font(.subheadline)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            if let onAddToList { footer(onAddToList) }
        }
    }

    // MARK: Sections

    private func header(_ detail: ProductDetailDisplay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let brand = detail.brand, !brand.isEmpty {
                Text(brand.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
            }
            Text(detail.description).font(.title2.bold())
            HStack(spacing: 6) {
                if let size = detail.size { Text(size) }
                if detail.size != nil, detail.ratingText != nil { Text("·") }
                if let rating = detail.ratingText {
                    Label(rating, systemImage: "star.fill")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func priceCard(_ detail: ProductDetailDisplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if detail.isOnPromo, let promo = detail.promoPriceText {
                    Text(promo).font(.title.bold()).foregroundStyle(.red)
                    if let regular = detail.regularPriceText {
                        Text(regular).foregroundStyle(.secondary).strikethrough()
                    }
                } else if let regular = detail.regularPriceText {
                    Text(regular).font(.title.bold())
                } else {
                    Text("Price unavailable").font(.headline).foregroundStyle(.secondary)
                }
            }
            if let perUnit = detail.pricePerUnitText {
                Text(perUnit).font(.subheadline).foregroundStyle(.secondary)
            }
            if let ends = detail.promoEndsText {
                Text(ends).font(.subheadline).foregroundStyle(.secondary)
            }
            if let stock = detail.stock { stockLabel(stock) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private func stockLabel(_ stock: ProductDetailDisplay.Stock) -> some View {
        switch stock {
        case .inStock:
            Label("In stock", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .lowStock:
            Label("Low stock", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
        case .outOfStock:
            Label("Temporarily out of stock", systemImage: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private func fulfillmentSection(_ detail: ProductDetailDisplay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ways to get it").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(detail.fulfillment, id: \.title) { option in
                    Label(
                        option.isAvailable ? option.title : "\(option.title) unavailable",
                        systemImage: option.isAvailable ? "checkmark" : "minus"
                    )
                    .font(.subheadline.weight(option.isAvailable ? .semibold : .regular))
                    .foregroundStyle(option.isAvailable ? Color.green : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 12, radius: 12)
                }
            }
        }
    }

    private func aisleRow(_ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Find it in store").font(.footnote).foregroundStyle(.secondary)
                Text(text).font(.headline)
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private func badgeRow(_ badges: [String]) -> some View {
        HStack {
            ForEach(badges, id: \.self) { badge in
                Text(badge)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
        }
    }

    private func allergenCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ALLERGENS").font(.caption.weight(.bold))
            Text(text).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func nutritionCard(_ detail: ProductDetailDisplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nutrition facts").font(.headline)
            if let serving = detail.servingText {
                Text("Serving size \(serving)").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(detail.nutrition, id: \.name) { row in
                Divider()
                HStack {
                    Text(row.name)
                    Spacer()
                    Text(row.value).fontWeight(.semibold)
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func footer(_ onAddToList: @escaping (KrogerProduct) -> Void) -> some View {
        HStack {
            Spacer()
            Button("Add to List") {
                if let product = viewModel.product { onAddToList(product) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.product == nil)
        }
        .padding()
        .background(.bar)
    }
}

// MARK: - Pieces

private struct ImageCarousel: View {
    let urls: [URL]

    var body: some View {
        TabView {
            if urls.isEmpty {
                placeholder
            } else {
                ForEach(urls, id: \.self) { url in
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fit).padding(20)
                        } else {
                            placeholder
                        }
                    }
                }
            }
        }
        .tabViewStyle(.page)
        .frame(height: 300)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "bag").font(.system(size: 40)).foregroundStyle(.tertiary)
    }
}

private extension View {
    func card(padding: CGFloat = 16, radius: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

#if DEBUG
private struct PreviewProductFetching: ProductFetching {
    func product(id: String, locationID: String?) async throws -> KrogerProduct {
        throw CancellationError() // Previews seed `detail` directly; this is never actually called.
    }
}

private let previewDetail = ProductDetailDisplay(
    id: "1",
    brand: "Golden Fields",
    description: "2% Reduced Fat Milk, Gallon",
    size: "1 gal",
    ratingText: "4.6 (128)",
    imageURLs: [],
    regularPrice: 3.79,
    promoPrice: 2.99,
    pricePerUnit: 0.02,
    promoEndsText: "Sale ends Oct 12, 2026",
    stock: .inStock,
    fulfillment: [
        .init(title: "In store", isAvailable: true),
        .init(title: "Curbside pickup", isAvailable: true),
        .init(title: "Delivery", isAvailable: true),
        .init(title: "Ship to home", isAvailable: false),
    ],
    aisleText: "Dairy · Aisle 7 · Left · Bay 4",
    badges: ["SNAP eligible", "Non-GMO"],
    allergensText: "Contains milk.",
    servingText: "1 cup (240 mL)",
    nutrition: [
        .init(name: "Calories", value: "120"),
        .init(name: "Total Fat", value: "5 g · 6%"),
        .init(name: "Sodium", value: "125 mg · 5%"),
    ],
    ingredients: "Reduced fat milk, vitamin A palmitate, vitamin D3."
)

#Preview("Detail") {
    NavigationStack {
        ProductDetailView(
            viewModel: ProductDetailViewModel(
                productID: "0001111041700", locationID: "01400943",
                products: PreviewProductFetching(), initialDetail: previewDetail
            ),
            onAddToList: { _ in }
        )
    }
}
#endif
