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
    /// Pre-computed OCR results, one entry per image (empty string if no text found).
    /// Used only locally - never forwarded to the LLM API.
    var ocrTexts: [String]?
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
    /// Whether the model should produce a reasoning trace. Only meaningful when
    /// `supportsThinking` is true.
    var thinkingEnabled: Bool = false
    /// Whether the selected model supports thinking at all. Used to decide
    /// whether to send the `think` field to Ollama (sending it to a
    /// non-thinking model returns an error).
    var supportsThinking: Bool = false
    /// First-token timeout in seconds for streaming requests. The connection is
    /// aborted only if the model produces no output within this window; once
    /// streaming begins, the connection stays open until the response completes.
    /// Only meaningful for HTTP-based providers (e.g. Ollama). On-device providers
    /// ignore it.
    var timeout: Double = 120
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
    case firstTokenTimeout(Double)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code, let body): return "LLM error \(code): \(body)"
        case .decoding(let s): return "Decoding error: \(s)"
        case .transport(let e): return "Transport: \(e.localizedDescription)"
        case .invalidConfig(let s): return "Invalid LLM config: \(s)"
        case .firstTokenTimeout(let seconds): return "No response from model within \(Int(seconds))s. The model may still be loading or is unresponsive."
        }
    }
}
