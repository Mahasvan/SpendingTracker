import Foundation

enum ToolKind: String, Codable, Sendable {
    case read
    case write
    case delete
}

@MainActor
protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var kind: ToolKind { get }
    var parameters: JSONValue { get }
    func run(arguments: JSONValue, context: ToolContext) async throws -> JSONValue
}

extension Tool {
    var schema: LLMToolSchema {
        LLMToolSchema(name: name, description: description, parameters: parameters)
    }
}

enum ToolError: Error, LocalizedError {
    case missingArgument(String)
    case invalidArgument(String, reason: String)
    case notFound(String)
    case cancelled
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let n): return "Missing argument: \(n)"
        case .invalidArgument(let n, let r): return "Invalid \(n): \(r)"
        case .notFound(let what): return "Not found: \(what)"
        case .cancelled: return "Cancelled by user"
        case .underlying(let e): return e.localizedDescription
        }
    }
}
