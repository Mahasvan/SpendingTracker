import Foundation

private enum ThinkingStreamState {
    case none
    case open
    case closed
}

final class OllamaClient: LLMClient, @unchecked Sendable {
    private let config: LLMConfig
    private let session: URLSession

    init(config: LLMConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func chat(messages: [LLMMessage], tools: [LLMToolSchema]) async throws -> LLMResponse {
        let req = try makeRequest(messages: messages, tools: tools, stream: false)
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw LLMError.transport(error)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw LLMError.transport(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.badStatus(http.statusCode, body)
        }
        return try parseSingle(data: data)
    }

    func stream(messages: [LLMMessage], tools: [LLMToolSchema]) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let req = try makeRequest(messages: messages, tools: tools, stream: true)
                    let (bytes, resp) = try await session.bytes(for: req)
                    guard let http = resp as? HTTPURLResponse else {
                        throw LLMError.transport(URLError(.badServerResponse))
                    }
                    if !(200..<300).contains(http.statusCode) {
                        var buf = Data()
                        for try await b in bytes { buf.append(b) }
                        let body = String(data: buf, encoding: .utf8) ?? ""
                        throw LLMError.badStatus(http.statusCode, body)
                    }
                    var accumulated = ""
                    var accumulatedToolCalls: [LLMToolCall] = []
                    var thinkingState: ThinkingStreamState = .none
                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8), !data.isEmpty else { continue }
                        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                        if let msg = obj["message"] as? [String: Any] {
                            if let thinking = msg["thinking"] as? String, !thinking.isEmpty {
                                if thinkingState == .none {
                                    let open = "<think>"
                                    accumulated += open
                                    continuation.yield(.textDelta(open))
                                    thinkingState = .open
                                }
                                accumulated += thinking
                                continuation.yield(.textDelta(thinking))
                            }
                            if let content = msg["content"] as? String, !content.isEmpty {
                                if thinkingState == .open {
                                    let close = "</think>\n\n"
                                    accumulated += close
                                    continuation.yield(.textDelta(close))
                                    thinkingState = .closed
                                }
                                accumulated += content
                                continuation.yield(.textDelta(content))
                            }
                            if let calls = msg["tool_calls"] as? [[String: Any]] {
                                for raw in calls {
                                    if let fn = raw["function"] as? [String: Any],
                                       let name = fn["name"] as? String {
                                        let argsAny = fn["arguments"]
                                        let args = JSONValue.from(any: argsAny)
                                        let callId = (raw["id"] as? String) ?? UUID().uuidString
                                        let call = LLMToolCall(id: callId, name: name, arguments: args)
                                        accumulatedToolCalls.append(call)
                                        continuation.yield(.toolCall(call))
                                    }
                                }
                            }
                        }
                        if let done = obj["done"] as? Bool, done {
                            if thinkingState == .open {
                                let close = "</think>"
                                accumulated += close
                                continuation.yield(.textDelta(close))
                                thinkingState = .closed
                            }
                            let finalMessage = LLMMessage(
                                role: .assistant,
                                content: accumulated,
                                name: nil,
                                toolCallId: nil,
                                toolCalls: accumulatedToolCalls.isEmpty ? nil : accumulatedToolCalls
                            )
                            continuation.yield(.done(LLMResponse(message: finalMessage, toolCalls: accumulatedToolCalls)))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeRequest(messages: [LLMMessage], tools: [LLMToolSchema], stream: Bool) throws -> URLRequest {
        let url = config.baseURL.appendingPathComponent("api/chat")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = config.timeout

        let sanitized = sanitizeHistory(messages)

        var body: [String: Any] = [
            "model": config.model,
            "stream": stream,
            "messages": sanitized.map(encodeMessage),
            "options": ["temperature": config.temperature]
        ]
        if let think = thinkParameter() {
            body["think"] = think
        }
        if !tools.isEmpty {
            body["tools"] = tools.map { encodeTool($0) }
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    /// Maps the configured thinking toggle to Ollama's `think` field.
    /// Returns nil when the model does not support thinking so the field is
    /// omitted (sending `think` to a non-thinking model is an error).
    /// gpt-oss only accepts string levels and cannot be fully disabled, so it
    /// maps on => "medium" and off => "low"; other models use a boolean.
    private func thinkParameter() -> Any? {
        guard config.supportsThinking else { return nil }
        let isGptOss = config.model.lowercased().contains("gpt-oss")
        if isGptOss {
            return config.thinkingEnabled ? "medium" : "low"
        }
        return config.thinkingEnabled
    }

    private func encodeMessage(_ m: LLMMessage) -> [String: Any] {
        var dict: [String: Any] = [
            "role": m.role.rawValue,
            "content": m.content
        ]
        if let name = m.name { dict["name"] = name }
        if let images = m.images, !images.isEmpty {
            dict["images"] = images
        }
        if let calls = m.toolCalls, !calls.isEmpty {
            dict["tool_calls"] = calls.map { call in
                [
                    "id": call.id,
                    "function": [
                        "name": call.name,
                        "arguments": jsonToFoundation(call.arguments)
                    ]
                ]
            }
        }
        return dict
    }

    private func sanitizeHistory(_ messages: [LLMMessage]) -> [LLMMessage] {
        messages.map { m in
            guard m.role == .assistant else { return m }
            let stripped = Self.stripThinking(m.content)
            if stripped == m.content { return m }
            return LLMMessage(
                role: m.role,
                content: stripped,
                name: m.name,
                toolCallId: m.toolCallId,
                toolCalls: m.toolCalls
            )
        }
    }

    private static let thinkingPatterns: [String] = [
        #"<think>[\s\S]*?</think>"#,
        #"<thinking>[\s\S]*?</thinking>"#,
        #"<reasoning>[\s\S]*?</reasoning>"#,
        #"<reflection>[\s\S]*?</reflection>"#
    ]

    static func stripThinking(_ content: String) -> String {
        var result = content
        for pattern in thinkingPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func encodeTool(_ t: LLMToolSchema) -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": t.name,
                "description": t.description,
                "parameters": jsonToFoundation(t.parameters)
            ]
        ]
    }

    private func jsonToFoundation(_ v: JSONValue) -> Any {
        switch v {
        case .null: return NSNull()
        case .bool(let b): return b
        case .number(let n): return n
        case .string(let s): return s
        case .array(let a): return a.map(jsonToFoundation)
        case .object(let o):
            var out: [String: Any] = [:]
            for (k, val) in o { out[k] = jsonToFoundation(val) }
            return out
        }
    }

    private func parseSingle(data: Data) throws -> LLMResponse {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.decoding("Top-level not object")
        }
        guard let msg = obj["message"] as? [String: Any] else {
            throw LLMError.decoding("No message")
        }
        let rawContent = (msg["content"] as? String) ?? ""
        let thinking = (msg["thinking"] as? String) ?? ""
        let content: String
        if thinking.isEmpty {
            content = rawContent
        } else {
            content = "<think>\(thinking)</think>\n\n\(rawContent)"
        }
        var toolCalls: [LLMToolCall] = []
        if let calls = msg["tool_calls"] as? [[String: Any]] {
            for raw in calls {
                if let fn = raw["function"] as? [String: Any],
                   let name = fn["name"] as? String {
                    let argsAny = fn["arguments"]
                    let args = JSONValue.from(any: argsAny)
                    let callId = (raw["id"] as? String) ?? UUID().uuidString
                    toolCalls.append(LLMToolCall(id: callId, name: name, arguments: args))
                }
            }
        }
        let message = LLMMessage(
            role: .assistant,
            content: content,
            name: nil,
            toolCallId: nil,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )
        return LLMResponse(message: message, toolCalls: toolCalls)
    }
}
