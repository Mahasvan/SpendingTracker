import Testing
import Foundation
@testable import Spending_Tracker

// Pure, synchronous tests for the date/time argument parsing used by the
// transaction tools. No SwiftData or async, so they run reliably.
struct DateArgParsingTests {
    private func parse(_ s: String) -> Date? {
        ToolArgs.date(.object(["date": .string(s)]), "date")
    }

    private func components(_ date: Date) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    @Test
    func parsesDateOnly() {
        let d = try? #require(parse("2026-06-02"))
        let c = components(d!)
        #expect(c.year == 2026)
        #expect(c.month == 6)
        #expect(c.day == 2)
    }

    @Test
    func parsesLocalDateTimeWithoutTimezone() {
        let d = try? #require(parse("2026-06-02T15:30"))
        let c = components(d!)
        #expect(c.year == 2026)
        #expect(c.month == 6)
        #expect(c.day == 2)
        #expect(c.hour == 15)
        #expect(c.minute == 30)
    }

    @Test
    func parsesLocalDateTimeWithSpaceAndSeconds() {
        let d = try? #require(parse("2026-06-02 15:30:45"))
        let c = components(d!)
        #expect(c.hour == 15)
        #expect(c.minute == 30)
        #expect(c.second == 45)
    }

    @Test
    func parsesISO8601WithTimezone() {
        #expect(parse("2026-06-02T15:30:00Z") != nil)
        #expect(parse("2026-06-02T15:30:00.123Z") != nil)
    }

    @Test
    func returnsNilForInvalidInput() {
        #expect(parse("not a date") == nil)
        #expect(parse("") == nil)
        #expect(ToolArgs.date(.object([:]), "date") == nil)
    }
}
