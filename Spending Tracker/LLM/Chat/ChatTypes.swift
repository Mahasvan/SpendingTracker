import Foundation

struct LLMToolCall: Codable, Sendable, Identifiable, Equatable {
    var id: String
    var name: String
    var arguments: JSONValue
}

struct LLMMessage: Codable, Sendable, Equatable {
    var role: ChatRole
    var content: String
    var name: String?
    var toolCallId: String?
    var toolCalls: [LLMToolCall]?
    var images: [String]?
}

struct LLMToolSchema: Codable, Sendable, Equatable {
    var name: String
    var description: String
    var parameters: JSONValue
}

struct LLMConfig: Sendable, Equatable {
    var provider: LLMProvider
    var baseURL: URL
    var model: String
    var temperature: Double
    var reasoning: ReasoningLevel = .off
}

struct LLMResponse: Sendable {
    var message: LLMMessage
    var toolCalls: [LLMToolCall]
}

enum LLMStreamChunk: Sendable {
    case textDelta(String)
    case toolCall(LLMToolCall)
    case done(LLMResponse)
}

enum LLMError: Error, LocalizedError {
    case badStatus(Int, String)
    case decoding(String)
    case transport(Error)
    case invalidConfig(String)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code, let body): return "LLM error \(code): \(body)"
        case .decoding(let s): return "Decoding error: \(s)"
        case .transport(let e): return "Transport: \(e.localizedDescription)"
        case .invalidConfig(let s): return "Invalid LLM config: \(s)"
        }
    }
}
