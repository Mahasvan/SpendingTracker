import Foundation

struct GetCurrentDateTimeTool: Tool {
    let name = "get_current_datetime"
    let description = """
    Get the current local date and time, weekday, timezone, and UTC offset. Call this to \
    resolve relative dates/times like "today", "yesterday", "now", "this morning", or "3pm" \
    into a concrete ISO-8601 value before creating or updating a transaction.
    """
    let kind: ToolKind = .read

    var parameters: JSONValue {
        JSONSchemaBuilder.object(properties: [:])
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        let now = Date.now
        let tz = TimeZone.current
        let offsetSeconds = tz.secondsFromGMT(for: now)

        let isoLocal = ISO8601DateFormatter()
        isoLocal.timeZone = tz
        isoLocal.formatOptions = [.withInternetDateTime]

        let isoUTC = ISO8601DateFormatter()
        isoUTC.timeZone = TimeZone(identifier: "UTC")
        isoUTC.formatOptions = [.withInternetDateTime]

        func fmt(_ format: String) -> String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = tz
            f.dateFormat = format
            return f.string(from: now)
        }

        let sign = offsetSeconds >= 0 ? "+" : "-"
        let absOffset = abs(offsetSeconds)
        let offsetString = String(format: "%@%02d:%02d", sign, absOffset / 3600, (absOffset % 3600) / 60)

        return .object([
            "iso8601": .string(isoLocal.string(from: now)),
            "iso8601_utc": .string(isoUTC.string(from: now)),
            "date": .string(fmt("yyyy-MM-dd")),
            "time": .string(fmt("HH:mm:ss")),
            "weekday": .string(fmt("EEEE")),
            "timezone": .string(tz.identifier),
            "utc_offset": .string(offsetString),
            "utc_offset_seconds": .number(Double(offsetSeconds))
        ])
    }
}
