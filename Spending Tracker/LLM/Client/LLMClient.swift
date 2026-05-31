import Foundation

protocol LLMClient: Sendable {
    func chat(
        messages: [LLMMessage],
        tools: [LLMToolSchema]
    ) async throws -> LLMResponse

    func stream(
        messages: [LLMMessage],
        tools: [LLMToolSchema]
    ) -> AsyncThrowingStream<LLMStreamChunk, Error>
}
