// Unit tests for the app's model, location and refresh logic. They use Swift Testing.
import Foundation
import Testing
@testable import RHDShopping

private func candidate(_ id: String, lat: Double?, lon: Double? = nil, hours: StoreHours? = nil) -> StoreCandidate {
    StoreCandidate(ref: StoreRef(id: id, name: "Store \(id)"), addressLine: "\(id) Main St",
                   point: lat.map { GeoPoint(latitude: $0, longitude: lon ?? -84.5) }, hours: hours)
}

// ~111 km per degree of latitude, so 0.001 deg is about 111 m
private let user = GeoPoint(latitude: 39.100, longitude: -84.5)

@Suite struct ResolverTests {
    @Test func picksTheClosestAndSkipsStoresWithoutALocation() throws {
        let match = try #require(StoreResolver.nearest(in: [
            candidate("far", lat: 39.150), candidate("none", lat: nil), candidate("near", lat: 39.110),
        ], to: user))
        #expect(match.store.ref.id == "near")
        #expect(!match.isInStore)
        #expect(StoreResolver.nearest(in: [candidate("none", lat: nil)], to: user) == nil)
    }

    @Test func inStoreWithinTheRadiusOnly() throws {
        let inside = try #require(StoreResolver.nearest(in: [candidate("a", lat: 39.1009)], to: user))   // ~100 m
        let outside = try #require(StoreResolver.nearest(in: [candidate("a", lat: 39.1020)], to: user))  // ~220 m
        #expect(inside.isInStore)
        #expect(!outside.isInStore)
    }
}

@Suite struct HoursTests {
    private func hours(open: String, close: String, tz: String = "UTC") -> StoreHours {
        let day = StoreHours.Day(open: open, close: close, isOpen24Hours: false)
        return StoreHours(timeZoneID: tz, days: Dictionary(uniqueKeysWithValues: (1...7).map { ($0, day) }))
    }
    private func at(_ hour: Int, _ minute: Int = 0, tz: String = "UTC") -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: tz)!
        return c.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: hour, minute: minute))!   // a Monday
    }

    @Test func openClosedBeforeAndAfter() {
        let h = hours(open: "06:00", close: "23:00")
        #expect(h.summary(at: at(12)) == "Open until 11 PM")
        #expect(h.summary(at: at(4)) == "Closed, opens 6 AM")
        #expect(h.summary(at: at(23, 30)) == "Closed, opens 6 AM")
    }

    @Test func halfHoursAndMidnightClose() {
        #expect(hours(open: "07:00", close: "21:30").summary(at: at(9)) == "Open until 9:30 PM")
        #expect(hours(open: "06:00", close: "01:00").summary(at: at(23)) == "Open until 1 AM")
    }

    @Test func twentyFourHoursAndMissingData() {
        #expect(StoreHours(isOpen24Hours: true, days: [:]).summary(at: at(3)) == "Open 24 hours")
        #expect(StoreHours(timeZoneID: "UTC", days: [:]).summary(at: at(3)) == nil)
    }

    @Test func usesTheStoresTimeZone() {
        let h = hours(open: "06:00", close: "23:00", tz: "America/Los_Angeles")
        // 20:00 UTC is 13:00 in Los Angeles (PDT): open. 08:00 UTC is 01:00 there: closed.
        #expect(h.summary(at: at(20)) == "Open until 11 PM")
        #expect(h.summary(at: at(8)) == "Closed, opens 6 AM")
    }
}

@MainActor final class FakeLocation: LocationProviding {
    var authorization: LocationAuthorization
    var grantsOnRequest: LocationAuthorization = .authorized
    var point: GeoPoint?
    init(_ authorization: LocationAuthorization, point: GeoPoint? = nil) { self.authorization = authorization; self.point = point }
    func requestAuthorization() async -> LocationAuthorization { authorization = grantsOnRequest; return authorization }
    func currentLocation() async throws -> GeoPoint {
        guard let point else { throw URLError(.cannotFindHost) }
        return point
    }
}

struct FakeSearch: StoreSearching {
    var nearby: [StoreCandidate] = []
    var byZIP: [StoreCandidate] = []
    var fails = false
    func stores(near point: GeoPoint) async throws -> [StoreCandidate] { if fails { throw URLError(.notConnectedToInternet) }; return nearby }
    func stores(zipCode: String) async throws -> [StoreCandidate] { if fails { throw URLError(.notConnectedToInternet) }; return byZIP }
}

@MainActor @Suite struct LocatorTests {
    func defaults(_ name: String) -> UserDefaults { let d = UserDefaults(suiteName: name)!; d.removePersistentDomain(forName: name); return d }

    @Test func permissionStatesBeforeAnyLookup() {
        #expect(StoreLocator(location: FakeLocation(.notDetermined), search: FakeSearch(), defaults: defaults("L1")).status == .needsPermission)
        #expect(StoreLocator(location: FakeLocation(.denied), search: FakeSearch(), defaults: defaults("L2")).status == .unavailable)
    }

    @Test func nearestWhenAwayAndInStoreWhenClose() async {
        let near = candidate("near", lat: 39.110)       // ~1.1 km away
        let here = candidate("here", lat: 39.1005)      // ~55 m away
        let away = StoreLocator(location: FakeLocation(.authorized, point: user), search: FakeSearch(nearby: [near]), defaults: defaults("L3"))
        await away.refresh()
        #expect(away.status == .nearest(near.ref))
        #expect(away.lastKnownPoint == user)

        let inside = StoreLocator(location: FakeLocation(.authorized, point: user), search: FakeSearch(nearby: [near, here]), defaults: defaults("L4"))
        await inside.refresh()
        #expect(inside.status == .inStore(here.ref))
    }

    @Test func chosenStoreBeatsNearestButNotBeingInAStore() async {
        let near = candidate("near", lat: 39.110), here = candidate("here", lat: 39.1005)
        let picked = StoreRef(id: "picked", name: "Picked")
        let d = defaults("L5")
        let locator = StoreLocator(location: FakeLocation(.authorized, point: user), search: FakeSearch(nearby: [near]), defaults: d)
        locator.choose(picked)
        #expect(locator.status == .chosen(picked))
        await locator.refresh()
        #expect(locator.status == .chosen(picked))                       // away: chosen wins over nearest

        let inside = StoreLocator(location: FakeLocation(.authorized, point: user), search: FakeSearch(nearby: [here]), defaults: d)
        await inside.refresh()
        #expect(inside.status == .inStore(here.ref))                     // in a store: that wins

        #expect(StoreLocator(location: FakeLocation(.denied), search: FakeSearch(), defaults: d).status == .chosen(picked))  // remembered
    }

    @Test func requestingPermissionThenLooksUpTheStore() async {
        let near = candidate("near", lat: 39.110)
        let fake = FakeLocation(.notDetermined, point: user)
        let locator = StoreLocator(location: fake, search: FakeSearch(nearby: [near]), defaults: defaults("L6"))
        await locator.requestPermission()
        #expect(locator.status == .nearest(near.ref))
        let denied = FakeLocation(.notDetermined, point: user); denied.grantsOnRequest = .denied
        let l2 = StoreLocator(location: denied, search: FakeSearch(), defaults: defaults("L7"))
        await l2.requestPermission()
        #expect(l2.status == .unavailable)
    }

    @Test func failuresFallBackToTheChosenStoreOrUnavailable() async {
        let broken = FakeSearch(fails: true)
        let l1 = StoreLocator(location: FakeLocation(.authorized, point: user), search: broken, defaults: defaults("L8"))
        await l1.refresh(); #expect(l1.status == .unavailable)
        let l2 = StoreLocator(location: FakeLocation(.authorized, point: nil), search: FakeSearch(), defaults: defaults("L9"))
        await l2.refresh(); #expect(l2.status == .unavailable)           // no fix
        let l3 = StoreLocator(location: FakeLocation(.authorized, point: user), search: broken, defaults: defaults("L10"))
        l3.choose(StoreRef(id: "p", name: "P")); await l3.refresh()
        #expect(l3.status == .chosen(StoreRef(id: "p", name: "P")))
    }

    @Test func clearingTheChosenStoreGoesBackToNearest() async {
        let near = candidate("near", lat: 39.110)
        let l = StoreLocator(location: FakeLocation(.authorized, point: user), search: FakeSearch(nearby: [near]), defaults: defaults("L11"))
        l.choose(StoreRef(id: "p", name: "P"))
        await l.clearChosenStore()
        #expect(l.status == .nearest(near.ref))
    }
}

@MainActor @Suite struct PickerTests {
    @Test func zipValidationAndRowsWithDistanceNearestFirst() async {
        #expect(StorePickerViewModel.normalizedZIP("45202") == "45202")
        #expect(StorePickerViewModel.normalizedZIP(" 45202-1234 ") == "45202")
        #expect(StorePickerViewModel.normalizedZIP("4520") == nil)
        #expect(StorePickerViewModel.normalizedZIP("abcde") == nil)

        let far = candidate("far", lat: 39.150), near = candidate("near", lat: 39.110)
        let vm = StorePickerViewModel(search: FakeSearch(byZIP: [far, near]), userPoint: { user })
        vm.zipCode = "45202"
        await vm.searchByZIP()
        #expect(vm.rows.map(\.ref.id) == ["near", "far"])
        #expect(vm.rows[0].distanceText == "0.7 mi")
        #expect(vm.hasSearched)

        let noUser = StorePickerViewModel(search: FakeSearch(byZIP: [far, near]), userPoint: { nil })
        noUser.zipCode = "45202"; await noUser.searchByZIP()
        #expect(noUser.rows.map(\.ref.id) == ["far", "near"])           // API order kept
        #expect(noUser.rows[0].distanceText == nil)
    }

    @Test func badZIPAndEmptyAndFailureMessages() async {
        let vm = StorePickerViewModel(search: FakeSearch(), userPoint: { nil })
        vm.zipCode = "12"; await vm.searchByZIP()
        #expect(vm.message == "Enter a 5-digit ZIP code.")
        vm.zipCode = "45202"; await vm.searchByZIP()
        #expect(vm.rows.isEmpty && vm.message == "No stores found nearby. Try another ZIP code.")
        let bad = StorePickerViewModel(search: FakeSearch(fails: true), userPoint: { nil })
        bad.zipCode = "45202"; await bad.searchByZIP()
        #expect(bad.message != nil && bad.hasSearched)
    }
}

@Suite struct ConfigTests {
    @Test func readsBothKeysAndRejectsMissingOrUnexpanded() throws {
        let ok = try AppConfiguration(info: ["KROGER_CLIENT_ID": " id ", "KROGER_CLIENT_SECRET": "secret"])
        #expect(ok == AppConfiguration(clientIDForTest: "id", secret: "secret"))
        #expect(throws: AppConfiguration.LoadError.missing(["KROGER_CLIENT_SECRET"])) {
            try AppConfiguration(info: ["KROGER_CLIENT_ID": "id"])
        }
        #expect(throws: AppConfiguration.LoadError.missing(["KROGER_CLIENT_ID", "KROGER_CLIENT_SECRET"])) {
            try AppConfiguration(info: ["KROGER_CLIENT_ID": "$(KROGER_CLIENT_ID)", "KROGER_CLIENT_SECRET": ""])
        }
    }
}

extension AppConfiguration {
    init(clientIDForTest id: String, secret: String) { try! self.init(info: ["KROGER_CLIENT_ID": id, "KROGER_CLIENT_SECRET": secret]) }
}
