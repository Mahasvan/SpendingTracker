import Foundation
import FoundationModels

/// LLMClient implementation using Apple's on-device Foundation Models (Apple Intelligence).
///
/// Tool calling is bridged by describing available tools in the system prompt and
/// parsing structured JSON tool-call output from the model's response. This avoids
/// the need for compile-time @Generable argument types for each of the app's 12 tools.
@available(macOS 26.0, iOS 26.0, *)
final class AppleFoundationClient: LLMClient, @unchecked Sendable {
    let config: LLMConfig

    init(config: LLMConfig) {
        self.config = config
    }

    // MARK: - LLMClient

    func chat(messages: [LLMMessage], tools: [LLMToolSchema]) async throws -> LLMResponse {
        let session = buildSession(messages: messages, tools: tools)

        guard let lastUserContent = messages.last(where: { $0.role == .user })?.content else {
            throw LLMError.invalidConfig("No user message found")
        }

        // Replay prior conversation turns for multi-turn context
        try await replayHistory(session: session, messages: messages)

        let response = try await session.respond(to: lastUserContent)
        return parseResponse(response.content)
    }

    func stream(messages: [LLMMessage], tools: [LLMToolSchema]) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = buildSession(messages: messages, tools: tools)

                    guard let lastUserContent = messages.last(where: { $0.role == .user })?.content else {
                        continuation.finish(throwing: LLMError.invalidConfig("No user message found"))
                        return
                    }

                    // Replay prior turns
                    try await replayHistory(session: session, messages: messages)

                    // Stream the final response
                    var fullText = ""
                    let stream = session.streamResponse(to: lastUserContent)

                    for try await partial in stream {
                        let currentContent = partial.content
                        // Yield only the new delta since last emission
                        if currentContent.count > fullText.count {
                            let newContent = String(currentContent.dropFirst(fullText.count))
                            fullText = currentContent
                            continuation.yield(.textDelta(newContent))
                        }
                    }

                    // Parse the final response for potential tool calls
                    let parsed = parseResponse(fullText)
                    continuation.yield(.done(parsed))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: LLMError.transport(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Session Building

    private func buildSession(messages: [LLMMessage], tools: [LLMToolSchema]) -> LanguageModelSession {
        // Extract system prompt from messages
        let systemContent = messages.first(where: { $0.role == .system })?.content ?? ""

        // Append tool descriptions so the model knows what tools are available
        let toolInstructions = buildToolInstructions(tools)

        let fullInstructions = systemContent + toolInstructions

        return LanguageModelSession(instructions: fullInstructions)
    }

    private func buildToolInstructions(_ tools: [LLMToolSchema]) -> String {
        guard !tools.isEmpty else { return "" }

        var desc = """

        \n\nYou have access to the following tools to help answer the user's questions.
        When you need to use a tool, respond with EXACTLY this JSON format on its own line, with NO other text on that line:
        {"tool_call": {"name": "<tool_name>", "arguments": {<arguments_as_json>}}}

        IMPORTANT: Only output ONE tool_call per response. Wait for the tool result before calling another tool.

        Available tools:

        """

        for tool in tools {
            desc += "• \(tool.name): \(tool.description)\n"
            desc += "  Parameters: \(tool.parameters.toString())\n\n"
        }

        desc += "If you don't need a tool, respond normally in natural language.\n"
        return desc
    }

    // MARK: - History Replay

    /// Replays conversation history by feeding prior user→assistant turns into the session,
    /// giving the model multi-turn context. Skips the last user message (which will be streamed).
    private func replayHistory(session: LanguageModelSession, messages: [LLMMessage]) async throws {
        // Pair up user messages with their corresponding assistant responses
        let conversational = messages.filter { $0.role == .user || $0.role == .assistant }
        guard conversational.count >= 2 else { return }

        // Process all user messages except the last one
        var i = 0
        while i < conversational.count - 1 {
            let msg = conversational[i]
            if msg.role == .user {
                // Feed the user message; the session's respond builds multi-turn context
                let _ = try await session.respond(to: msg.content)
            }
            i += 1
        }
    }

    // MARK: - Response Parsing

    /// Parses the model's text response, extracting any tool call JSON if present.
    private func parseResponse(_ text: String) -> LLMResponse {
        var toolCalls: [LLMToolCall] = []
        var cleanedText = text

        // Look for tool call pattern: {"tool_call": {"name": "...", "arguments": {...}}}
        let pattern = #"\{\s*"tool_call"\s*:\s*\{\s*"name"\s*:\s*"([^"]+)"\s*,\s*"arguments"\s*:\s*(\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\})\s*\}\s*\}"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

            for match in matches {
                guard match.numberOfRanges >= 3,
                      let nameRange = Range(match.range(at: 1), in: text),
                      let argsRange = Range(match.range(at: 2), in: text) else { continue }

                let name = String(text[nameRange])
                let argsString = String(text[argsRange])

                if let argsData = argsString.data(using: .utf8),
                   let argsObj = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                    let call = LLMToolCall(id: UUID().uuidString, name: name, arguments: JSONValue.from(any: argsObj))
                    toolCalls.append(call)
                }

                // Remove the tool call JSON from displayed text
                if let fullRange = Range(match.range, in: text) {
                    cleanedText = cleanedText.replacingCharacters(in: fullRange, with: "")
                }
            }
        }

        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        let msg = LLMMessage(
            role: .assistant,
            content: cleanedText,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )
        return LLMResponse(message: msg, toolCalls: toolCalls)
    }
}
