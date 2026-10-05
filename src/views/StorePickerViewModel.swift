import Foundation

/// One store in the picker: what a person needs to tell stores apart.
struct StoreRow: Identifiable, Hashable {
    let ref: StoreRef
    let addressLine: String?
    /// "0.8 mi", when the device's position is known.
    let distanceText: String?
    /// "Open until 11 PM", when the hours say.
    let hoursText: String?

    var id: String { ref.id }

    /// "0.8 mi \u{B7} Open until 11 PM", with whichever parts exist.
    var detailText: String? {
        let parts = [distanceText, hoursText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{B7} ")
    }
}

/// Drives the store picker: search by ZIP code or near the device, and show
/// the stores with distance and hours.
@MainActor
final class StorePickerViewModel: ObservableObject {
    @Published var zipCode = ""
    @Published private(set) var rows: [StoreRow] = []
    @Published private(set) var isSearching = false
    @Published private(set) var message: String?
    /// Whether a search has run, to tell "no results" from "haven't searched".
    @Published private(set) var hasSearched = false

    private let search: StoreSearching
    private let userPoint: () -> GeoPoint?
    private let now: () -> Date

    init(search: StoreSearching, userPoint: @escaping () -> GeoPoint?, now: @escaping () -> Date = Date.init) {
        self.search = search
        self.userPoint = userPoint
        self.now = now
    }

    /// A US ZIP code is five digits (ZIP+4 is also accepted and trimmed).
    static func normalizedZIP(_ text: String) -> String? {
        let digits = text.trimmingCharacters(in: .whitespaces)
        let base = digits.split(separator: "-").first.map(String.init) ?? digits
        return base.count == 5 && base.allSatisfy(\.isNumber) ? base : nil
    }

    var canSearchZIP: Bool { Self.normalizedZIP(zipCode) != nil && !isSearching }

    func searchByZIP() async {
        guard let zip = Self.normalizedZIP(zipCode) else {
            message = "Enter a 5-digit ZIP code."
            return
        }
        await run { try await self.search.stores(zipCode: zip) }
    }

    /// Searches around a known point (the device's position).
    func searchNear(_ point: GeoPoint) async {
        await run { try await self.search.stores(near: point) }
    }

    private func run(_ lookup: () async throws -> [StoreCandidate]) async {
        isSearching = true
        message = nil
        defer { isSearching = false }
        do {
            let found = try await lookup()
            rows = Self.rows(from: found, from: userPoint(), at: now())
            hasSearched = true
            if rows.isEmpty { message = "No stores found nearby. Try another ZIP code." }
        } catch is CancellationError {
            return
        } catch {
            hasSearched = true
            message = (error as? LocalizedError)?.errorDescription ?? "Couldn't load stores. Please try again."
        }
    }

    /// Candidates as rows, nearest first when the device's position is known.
    static func rows(from candidates: [StoreCandidate], from user: GeoPoint?, at now: Date) -> [StoreRow] {
        let withDistance: [(StoreCandidate, Double?)] = candidates.map { candidate in
            (candidate, user.flatMap { user in candidate.point.map { user.distance(to: $0) } })
        }
        let ordered = user == nil
            ? withDistance
            : withDistance.sorted { ($0.1 ?? .greatestFiniteMagnitude) < ($1.1 ?? .greatestFiniteMagnitude) }
        return ordered.map { candidate, meters in
            StoreRow(
                ref: candidate.ref,
                addressLine: candidate.addressLine,
                distanceText: meters.map(distanceText),
                hoursText: candidate.hours?.summary(at: now)
            )
        }
    }

    private static func distanceText(_ meters: Double) -> String {
        let miles = meters / 1609.344
        return miles < 0.1 ? "Here" : "\(miles.formatted(.number.precision(.fractionLength(1)))) mi"
    }
}
