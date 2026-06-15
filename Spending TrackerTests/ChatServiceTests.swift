import Testing
import Foundation
import SwiftData
@testable import Spending_Tracker

// Scripted LLM client for tests. Returns prepared responses in order.
final class MockLLMClient: LLMClient, @unchecked Sendable {
    var scriptedTextThenTools: [(text: String, calls: [LLMToolCall])]
    var receivedMessageCounts: [Int] = []
    var lastReceivedRoles: [ChatRole] = []
    var lastReceivedSystemContent: String?
    var lock = NSLock()

    init(_ scripted: [(text: String, calls: [LLMToolCall])]) {
        self.scriptedTextThenTools = scripted
    }

    func chat(messages: [LLMMessage], tools: [LLMToolSchema]) async throws -> LLMResponse {
        return try take(messages: messages)
    }

    func stream(messages: [LLMMessage], tools: [LLMToolSchema]) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            do {
                let resp = try take(messages: messages)
                if !resp.message.content.isEmpty {
                    continuation.yield(.textDelta(resp.message.content))
                }
                for call in resp.toolCalls {
                    continuation.yield(.toolCall(call))
                }
                continuation.yield(.done(resp))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    private func take(messages: [LLMMessage]) throws -> LLMResponse {
        lock.lock(); defer { lock.unlock() }
        receivedMessageCounts.append(messages.count)
        lastReceivedRoles = messages.map(\.role)
        lastReceivedSystemContent = messages.first { $0.role == .system }?.content
        guard !scriptedTextThenTools.isEmpty else {
            throw LLMError.invalidConfig("ran out of scripted responses")
        }
        let entry = scriptedTextThenTools.removeFirst()
        let msg = LLMMessage(
            role: .assistant,
            content: entry.text,
            name: nil,
            toolCallId: nil,
            toolCalls: entry.calls.isEmpty ? nil : entry.calls
        )
        return LLMResponse(message: msg, toolCalls: entry.calls)
    }
}

@MainActor
struct ChatServiceTests {
    private func makeService(
        scripted: [(String, [LLMToolCall])],
        maxHistory: Int? = nil
    ) throws -> (ChatService, ToolContext, MockLLMClient) {
        let container = try TestSupport.makeContainer()
        TestSupport.seedDefaults(in: container)
        let ctx = container.mainContext
        let toolCtx = ToolContext(
            transactionRepo: SwiftDataTransactionRepository(context: ctx),
            categoryRepo: SwiftDataCategoryRepository(context: ctx),
            paymentMethodRepo: SwiftDataPaymentMethodRepository(context: ctx),
            budgetRepo: SwiftDataBudgetRepository(context: ctx)
        )
        let registry = ToolRegistry.defaultRegistry()
        let mock = MockLLMClient(scripted)
        let settings = AppSettings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        settings.readPolicy = .auto
        settings.writePolicy = .auto
        settings.deletePolicy = .auto
        if let maxHistory { settings.maxHistoryMessages = maxHistory }
        let service = ChatService(
            clientFactory: { _ in mock },
            registry: registry,
            toolContext: toolCtx,
            settings: settings
        )
        return (service, toolCtx, mock)
    }

    @Test @MainActor
    func plainTextResponse() async throws {
        let (service, _, _) = try makeService(scripted: [("Hello, how can I help?", [])])
        await service.send(userText: "hi")
        #expect(service.messages.last?.role == .assistant)
        #expect(service.messages.last?.content == "Hello, how can I help?")
    }

    @Test @MainActor
    func firstMessageIsAlwaysDatedSystemPrompt() async throws {
        let (service, _, mock) = try makeService(scripted: [("ok", [])])
        await service.send(userText: "hi")
        // The mock records the messages it was handed; the first must be the system prompt.
        #expect(mock.lastReceivedRoles.first == .system)
        #expect(mock.lastReceivedSystemContent?.contains("Today's date:") == true)
    }

    @Test @MainActor
    func historyIsTruncatedToConfiguredLimit() async throws {
        let limit = 4
        let scripted = Array(repeating: ("ok", [LLMToolCall]()), count: 12)
        let (service, _, mock) = try makeService(scripted: scripted, maxHistory: limit)
        for i in 0..<12 {
            await service.send(userText: "message \(i)")
        }
        // Every request is capped at system prompt (1) + at most `limit` trailing messages.
        for count in mock.receivedMessageCounts {
            #expect(count <= limit + 1)
        }
        // The last request should actually hit the cap given enough history.
        #expect(mock.receivedMessageCounts.last == limit + 1)
        // Full local history is still retained (not mutated by truncation).
        #expect(service.messages.count == 1 + 24)
    }

    @Test @MainActor
    func shortHistoryIsNotTruncated() async throws {
        let (service, _, mock) = try makeService(scripted: [("a", []), ("b", [])], maxHistory: 40)
        await service.send(userText: "one")
        await service.send(userText: "two")
        // 2nd request: system + (user, assistant, user) = 4 messages, below the cap.
        #expect(mock.receivedMessageCounts.last == 4)
    }

    @Test @MainActor
    func detectsToolLoopAndStops() async throws {
        // Simulate a loop: the model keeps calling the same tool with the same args
        let loopCall = LLMToolCall(id: "1", name: "get_categories", arguments: .object([:]))
        let scripted = Array(repeating: ("Checking categories...", [loopCall]), count: 10)
        let (service, _, _) = try makeService(scripted: scripted)
        await service.send(userText: "show me categories")
        // Should stop after detecting the loop (maxConsecutiveRepeats = 3)
        // The service should have a message indicating it stopped
        let hasStopMessage = service.messages.contains { $0.content.contains("detected tool loop") }
        #expect(hasStopMessage)
    }

    @Test @MainActor
    func stopsAtToolRoundsCeiling() async throws {
        // Simulate many different tool calls to hit the ceiling
        let scripted = (0..<30).map { i in
            let call = LLMToolCall(id: "\(i)", name: "get_categories", arguments: .object(["page": .number(Double(i))]))
            return ("Checking page \(i)...", [call])
        }
        let (service, _, _) = try makeService(scripted: scripted)
        await service.send(userText: "list everything")
        // Should stop at the ceiling (25 rounds)
        let hasCeilingMessage = service.messages.contains { $0.content.contains("maximum tool rounds reached") }
        #expect(hasCeilingMessage)
    }
}
