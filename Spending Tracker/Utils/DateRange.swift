import Foundation

struct DateRange: Equatable, Sendable {
    var start: Date
    var end: Date

    static var thisMonth: DateRange {
        let cal = Calendar.current
        let now = Date.now
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? now
        return DateRange(start: start, end: end)
    }

    static var lastMonth: DateRange {
        let cal = Calendar.current
        let now = Date.now
        let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let start = cal.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
        let end = cal.date(byAdding: DateComponents(second: -1), to: thisMonthStart) ?? now
        return DateRange(start: start, end: end)
    }

    static var last30Days: DateRange {
        let cal = Calendar.current
        let now = Date.now
        let start = cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: now)) ?? now
        return DateRange(start: start, end: now)
    }

    static var allTime: DateRange {
        DateRange(start: Date(timeIntervalSince1970: 0), end: .distantFuture)
    }

    func contains(_ d: Date) -> Bool {
        d >= start && d <= end
    }
}
