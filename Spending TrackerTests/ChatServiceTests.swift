import Testing
import Foundation
import SwiftData
@testable import Spending_Tracker

// Scripted LLM client for tests. Returns prepared responses in order.
final class MockLLMClient: LLMClient, @unchecked Sendable {
    var scriptedTextThenTools: [(text: String, calls: [LLMToolCall])]
    var receivedMessageCounts: [Int] = []
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
    private func makeService(scripted: [(String, [LLMToolCall])]) throws -> (ChatService, ToolContext, MockLLMClient) {
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

}
