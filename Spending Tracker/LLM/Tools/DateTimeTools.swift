import Foundation

struct GetCurrentDateTimeTool: Tool {
    let name = "get_current_datetime"
    let description = """
    Get the current UTC date and time, weekday, and timezone. Call this to \
    resolve relative dates/times like "today", "yesterday", "now", "this morning", or "3pm" \
    into a concrete ISO-8601 value before creating or updating a transaction. \
    All times are UTC; always pass UTC ISO-8601 values to tools.
    """
    let kind: ToolKind = .read

    var parameters: JSONValue {
        JSONSchemaBuilder.object(properties: [:])
    }

    private static let isoUTC: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let componentFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        let now = Date.now
        let isoUTC = Self.isoUTC

        func fmt(_ format: String) -> String {
            let f = Self.componentFormatter
            f.dateFormat = format
            return f.string(from: now)
        }

        return .object([
            "iso8601": .string(isoUTC.string(from: now)),
            "date": .string(fmt("yyyy-MM-dd")),
            "time": .string(fmt("HH:mm:ss")),
            "weekday": .string(fmt("EEEE")),
            "timezone": .string("UTC")
        ])
    }
}
