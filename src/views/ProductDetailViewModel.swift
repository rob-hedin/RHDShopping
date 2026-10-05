import Foundation
import RHKrogerAPI

/// Drives the product detail screen: fetches one product at the known store
/// and exposes it as a display-ready value.
@MainActor
final class ProductDetailViewModel: ObservableObject {
    @Published private(set) var detail: ProductDetailDisplay?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let productID: String
    private let locationID: String
    private let products: ProductFetching

    /// The full API model behind `detail`, handed back by `product` so the
    /// caller (the shopping list) gets everything, not just what's displayed.
    private var sourceProduct: KrogerProduct?

    /// - Parameter initialDetail: Lets a preview or test seed the screen
    ///   directly, bypassing the network call `load()` would make.
    init(
        productID: String,
        locationID: String,
        products: ProductFetching,
        initialDetail: ProductDetailDisplay? = nil
    ) {
        self.productID = productID
        self.locationID = locationID
        self.products = products
        self.detail = initialDetail
    }

    /// The full-detail product, for the caller to add to the shopping list.
    var product: KrogerProduct? { sourceProduct }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let product = try await products.product(id: productID, locationID: locationID)
            sourceProduct = product
            detail = product.asDetailDisplay()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't load this product. Please try again."
        }
    }
}
