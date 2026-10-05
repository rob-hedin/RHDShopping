import Foundation
import RHKrogerAPI

/// A store's weekly opening hours, in the store's own time zone, with a
/// plain-language summary for "right now" ("Open until 11 PM").
struct StoreHours: Hashable, Sendable {
    struct Day: Hashable, Sendable {
        /// Local `HH:mm` strings, as the service delivers them.
        let open: String?
        let close: String?
        let isOpen24Hours: Bool
    }

    let timeZoneID: String?
    let isOpen24Hours: Bool
    /// Keyed by `Calendar` weekday: 1 is Sunday ... 7 is Saturday.
    let days: [Int: Day]

    init(timeZoneID: String? = nil, isOpen24Hours: Bool = false, days: [Int: Day]) {
        self.timeZoneID = timeZoneID
        self.isOpen24Hours = isOpen24Hours
        self.days = days
    }

    init(_ hours: KrogerWeeklyHours) {
        func day(_ d: KrogerDailyHours?) -> Day? {
            d.map { Day(open: $0.open, close: $0.close, isOpen24Hours: $0.isOpen24Hours) }
        }
        let all: [(Int, Day?)] = [
            (1, day(hours.sunday)), (2, day(hours.monday)), (3, day(hours.tuesday)), (4, day(hours.wednesday)),
            (5, day(hours.thursday)), (6, day(hours.friday)), (7, day(hours.saturday)),
        ]
        self.init(
            timeZoneID: hours.timeZone,
            isOpen24Hours: hours.isOpen24Hours,
            days: Dictionary(uniqueKeysWithValues: all.compactMap { weekday, day in day.map { (weekday, $0) } })
        )
    }

    /// "Open 24 hours", "Open until 11 PM", or "Closed, opens 6 AM"; nil when
    /// the hours don't say enough to tell.
    func summary(at now: Date) -> String? {
        if isOpen24Hours { return "Open 24 hours" }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
        let weekday = calendar.component(.weekday, from: now)

        if let today = days[weekday] {
            if today.isOpen24Hours { return "Open 24 hours" }
            if let open = today.open.flatMap(Self.minutes), let close = today.close.flatMap(Self.minutes) {
                let current = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
                // A close at or before the open means it runs past midnight.
                let end = close <= open ? close + 24 * 60 : close
                if current >= open, current < end { return "Open until \(Self.label(close))" }
                if current < open { return "Closed, opens \(Self.label(open))" }
            }
        }
        // After closing, or no hours today: the next day with an opening time.
        for offset in 1...7 {
            let next = (weekday - 1 + offset) % 7 + 1
            if let open = days[next]?.open.flatMap(Self.minutes) {
                return "Closed, opens \(Self.label(open))" + (offset == 1 ? "" : " \(Self.dayName(next))")
            }
        }
        return nil
    }

    private static func minutes(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    /// "6 AM", "11:30 PM".
    private static func label(_ minutes: Int) -> String {
        let hour24 = (minutes / 60) % 24
        let minute = minutes % 60
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let suffix = hour24 < 12 ? "AM" : "PM"
        return minute == 0 ? "\(hour12) \(suffix)" : "\(hour12):\(String(format: "%02d", minute)) \(suffix)"
    }

    private static func dayName(_ weekday: Int) -> String {
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][weekday - 1]
    }
}
