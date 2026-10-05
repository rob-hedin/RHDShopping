import Foundation
import RHKrogerAPI

/// A display-ready view of one `KrogerProduct` for the product detail screen.
///
/// Same seam as `ProductDisplayItem`: `KrogerProduct` can't be constructed
/// outside RHKrogerAPI, so the screen works with this plain struct (which
/// Previews can build) and `KrogerProduct.asDetailDisplay()` is the one
/// place that maps real API data onto it.
struct ProductDetailDisplay: Identifiable, Hashable {
    enum Stock: Hashable {
        case inStock, lowStock, outOfStock
    }

    struct FulfillmentOption: Hashable {
        let title: String
        let isAvailable: Bool
    }

    struct NutritionRow: Hashable {
        let name: String
        let value: String
    }

    let id: String
    let brand: String?
    let description: String
    let size: String?
    let ratingText: String?
    let imageURLs: [URL]

    let regularPrice: Decimal?
    let promoPrice: Decimal?
    let pricePerUnit: Decimal?
    let promoEndsText: String?
    let stock: Stock?

    let fulfillment: [FulfillmentOption]
    let aisleText: String?
    let badges: [String]
    let allergensText: String?
    let servingText: String?
    let nutrition: [NutritionRow]
    let ingredients: String?

    var isOnPromo: Bool { promoPrice != nil }
    var regularPriceText: String? { regularPrice?.formatted(.currency(code: "USD")) }
    var promoPriceText: String? { promoPrice?.formatted(.currency(code: "USD")) }
    var pricePerUnitText: String? {
        guard let pricePerUnit else { return nil }
        return "\(pricePerUnit.formatted(.currency(code: "USD"))) per unit"
    }
}

extension KrogerProduct {
    /// Maps this product onto what the detail screen displays. Like the
    /// picker, it reads the first item only; a size picker for multi-item
    /// products is out of scope here.
    func asDetailDisplay() -> ProductDetailDisplay {
        let item = items.first
        let price = item?.price ?? item?.nationalPrice
        let promo = Self.activePromo(price)
        let nutrition = nutritionInformation.first

        return ProductDetailDisplay(
            id: id,
            brand: brand,
            description: description ?? receiptDescription ?? "Unnamed product",
            size: item?.size,
            ratingText: ratingText,
            imageURLs: imageURLs,
            regularPrice: price?.regular,
            promoPrice: promo,
            pricePerUnit: promo != nil ? price?.promoPerUnitEstimate : price?.regularPerUnitEstimate,
            promoEndsText: promo != nil
                ? price?.expirationDate.map { "Sale ends \($0.formatted(date: .abbreviated, time: .omitted))" }
                : nil,
            stock: item?.stockLevel.flatMap(Self.stock),
            fulfillment: item?.fulfillment.map(Self.fulfillmentOptions) ?? [],
            aisleText: aisleLocations.first.flatMap(Self.aisleText),
            badges: badges,
            allergensText: allergensDescription
                ?? (allergens.isEmpty ? nil : allergens.compactMap(\.name).joined(separator: ", ")),
            servingText: nutrition?.servingSize?.description,
            nutrition: nutrition?.nutrients.compactMap(Self.nutritionRow) ?? [],
            ingredients: nutrition?.ingredientStatement
        )
    }

    private var ratingText: String? {
        guard let average = ratings?.averageOverallRating else { return nil }
        let rating = average.formatted(.number.precision(.fractionLength(1)))
        guard let count = ratings?.totalReviewCount else { return rating }
        return "\(rating) (\(count))"
    }

    /// Every size of every image, largest first within an image, with the
    /// default image leading.
    private var imageURLs: [URL] {
        let sizePreference = ["xlarge", "large", "medium", "small", "thumbnail"]
        let ordered = images.filter(\.isDefault) + images.filter { !$0.isDefault }
        return ordered.compactMap { image in
            for size in sizePreference {
                if let url = image.sizes.first(where: { $0.size?.lowercased() == size })?.url { return url }
            }
            return image.sizes.compactMap(\.url).first
        }
    }

    private var badges: [String] {
        var result: [String] = []
        if isSNAPEligible == true { result.append("SNAP eligible") }
        if isNonGMO == true { result.append("Non-GMO") }
        if organicClaimName != nil { result.append("Organic") }
        if hasAgeRestriction == true { result.append("Age restricted") }
        return result
    }

    static func stock(_ level: KrogerStockLevel) -> ProductDetailDisplay.Stock? {
        switch level {
        case .high: .inStock
        case .low: .lowStock
        case .temporarilyOutOfStock: .outOfStock
        case .unknown: nil
        }
    }

    private static func fulfillmentOptions(_ modalities: KrogerModalities) -> [ProductDetailDisplay.FulfillmentOption] {
        [
            .init(title: "In store", isAvailable: modalities.inStore),
            .init(title: "Curbside pickup", isAvailable: modalities.curbside),
            .init(title: "Delivery", isAvailable: modalities.delivery),
            .init(title: "Ship to home", isAvailable: modalities.shipToHome),
        ]
    }

    private static func aisleText(_ aisle: KrogerAisleLocation) -> String? {
        let parts = [aisle.description, aisle.number.map { "Aisle \($0)" }, aisle.side, aisle.bayNumber.map { "Bay \($0)" }]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func nutritionRow(_ nutrient: KrogerNutrient) -> ProductDetailDisplay.NutritionRow? {
        guard let name = nutrient.displayName ?? nutrient.description else { return nil }
        var parts: [String] = []
        if let quantity = nutrient.quantity {
            let unit = nutrient.unitOfMeasure?.abbreviation.map { " \($0)" } ?? ""
            parts.append(quantity.formatted(.number.precision(.fractionLength(0...1))) + unit)
        }
        if let percent = nutrient.percentDailyIntake {
            parts.append("\(percent.formatted(.number.precision(.fractionLength(0))))%")
        }
        guard !parts.isEmpty else { return nil }
        return .init(name: name, value: parts.joined(separator: " · "))
    }
}
