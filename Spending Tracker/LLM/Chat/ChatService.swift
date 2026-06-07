import Foundation
import Observation

@MainActor
@Observable
final class ChatService {
    private(set) var messages: [LLMMessage] = []
    private(set) var isBusy: Bool = false
    var streamingAssistantText: String = ""
    var errorMessage: String?

    var pendingConfirmation: ToolConfirmRequest?

    private let clientFactory: @MainActor (LLMConfig) -> LLMClient
    private let registry: ToolRegistry
    private let toolContext: ToolContext
    private let settings: AppSettings
    private let capabilityStore: ModelCapabilityStore?
    private let maxToolIterations = 8

    private let systemPrompt = """
    You are a spending-tracker assistant. The user manages INR transactions. Use tools only—never guess. Format money as ₹X.XX. Be concise and keep reasoning brief.

    Transaction rules:
    - add_transaction requires: "amount" (positive number) and "type" (exactly "expense" or "income"). Infer type from wording; if unclear, default to "expense". Amount is always positive; direction comes from type.
    - Include category, payment_method, date, and note in the same add_transaction call when known. Do not add then immediately update.
    - update_transaction and delete_transaction need a real UUID id. Fetch ids with list_transactions or search_transactions first; never invent them.

    Dates: call get_current_datetime for relative times (today, yesterday, 3pm). Pass ISO-8601 dates to tools. Include time only when specified. Omit date to default to now.

    Categories: call get_categories before adding/updating, pick the best existing one, and pass it. For income, default category to "Salary" and payment method to "Bank Transfer". Category and payment_method are optional; skip if nothing fits.

    Today's date: \(ISO8601DateFormatter.shared.string(from: .now)).
    """

    init(
        clientFactory: @escaping @MainActor (LLMConfig) -> LLMClient = { LLMClientFactory.make($0) },
        registry: ToolRegistry,
        toolContext: ToolContext,
        settings: AppSettings,
        capabilityStore: ModelCapabilityStore? = nil
    ) {
        self.clientFactory = clientFactory
        self.registry = registry
        self.toolContext = toolContext
        self.settings = settings
        self.capabilityStore = capabilityStore
        self.messages = [LLMMessage(role: .system, content: systemPrompt)]
    }

    func reset() {
        messages = [LLMMessage(role: .system, content: systemPrompt)]
        streamingAssistantText = ""
        errorMessage = nil
        pendingConfirmation = nil
    }

    func send(userText: String, images: [String] = []) async {
        guard !isBusy else { return }
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty else { return }
        messages.append(LLMMessage(
            role: .user,
            content: trimmed,
            images: images.isEmpty ? nil : images
        ))
        await runLoop()
    }

    func approve(_ request: ToolConfirmRequest) async {
        guard pendingConfirmation?.id == request.id else { return }
        pendingConfirmation = nil
        await executeApproved(call: request.call)
    }

    func reject(_ request: ToolConfirmRequest) async {
        guard pendingConfirmation?.id == request.id else { return }
        pendingConfirmation = nil
        messages.append(LLMMessage(
            role: .tool,
            content: "{\"error\": \"User rejected tool call\"}",
            name: request.call.name,
            toolCallId: request.call.id
        ))
        await continueAfterTool()
    }

    private func runLoop() async {
        isBusy = true
        defer { isBusy = false }
        await stepStream()
    }

    private func stepStream() async {
        streamingAssistantText = ""
        let cfg = currentConfig()
        let client = clientFactory(cfg)
        let schemas = registry.schemas()

        var aggregatedToolCalls: [LLMToolCall] = []
        var aggregatedText = ""

        do {
            for try await chunk in client.stream(messages: messages, tools: schemas) {
                switch chunk {
                case .textDelta(let s):
                    aggregatedText += s
                    streamingAssistantText = aggregatedText
                case .toolCall(let call):
                    aggregatedToolCalls.append(call)
                case .done:
                    break
                }
            }
        } catch {
            errorMessage = (error as? LLMError)?.errorDescription ?? error.localizedDescription
            return
        }

        let assistantMessage = LLMMessage(
            role: .assistant,
            content: aggregatedText,
            name: nil,
            toolCallId: nil,
            toolCalls: aggregatedToolCalls.isEmpty ? nil : aggregatedToolCalls
        )
        messages.append(assistantMessage)
        streamingAssistantText = ""

        if !aggregatedToolCalls.isEmpty {
            await processToolCalls(aggregatedToolCalls)
        }
    }

    private func processToolCalls(_ calls: [LLMToolCall]) async {
        let toolIterations = messages.filter { $0.role == .tool }.count
        guard toolIterations < maxToolIterations else {
            messages.append(LLMMessage(role: .assistant, content: "(Stopped: tool iteration limit reached)"))
            return
        }
        for call in calls {
            guard let tool = registry.tool(named: call.name) else {
                messages.append(LLMMessage(
                    role: .tool,
                    content: "{\"error\": \"Unknown tool '\(call.name)'\"}",
                    name: call.name,
                    toolCallId: call.id
                ))
                continue
            }
            let policy = policyFor(kind: tool.kind)
            switch policy {
            case .auto:
                await execute(call: call)
            case .disabled:
                messages.append(LLMMessage(
                    role: .tool,
                    content: "{\"error\": \"Tool '\(call.name)' is disabled by user policy\"}",
                    name: call.name,
                    toolCallId: call.id
                ))
            case .confirm:
                pendingConfirmation = ToolConfirmRequest(id: UUID(), call: call, kind: tool.kind)
                return
            }
        }
        if pendingConfirmation == nil {
            await continueAfterTool()
        }
    }

    private func executeApproved(call: LLMToolCall) async {
        isBusy = true
        defer { isBusy = false }
        await execute(call: call)
        // After approving and executing, also process any *remaining* tool calls in the last assistant
        // message that were waiting for this confirmation.
        if let last = messages.last(where: { $0.role == .assistant && $0.toolCalls != nil }) {
            let alreadyHandled = Set(messages.compactMap { $0.toolCallId })
            let remaining = (last.toolCalls ?? []).filter { !alreadyHandled.contains($0.id) }
            if !remaining.isEmpty {
                await processToolCalls(remaining)
                if pendingConfirmation != nil { return }
            }
        }
        await continueAfterTool()
    }

    private func execute(call: LLMToolCall) async {
        guard let tool = registry.tool(named: call.name) else { return }
        do {
            let result = try await tool.run(arguments: call.arguments, context: toolContext)
            messages.append(LLMMessage(
                role: .tool,
                content: result.toString(),
                name: call.name,
                toolCallId: call.id
            ))
        } catch {
            let msg = (error as? ToolError)?.errorDescription ?? error.localizedDescription
            messages.append(LLMMessage(
                role: .tool,
                content: "{\"error\": \"\(escapeJSON(msg))\"}",
                name: call.name,
                toolCallId: call.id
            ))
        }
    }

    private func continueAfterTool() async {
        await stepStream()
    }

    private func policyFor(kind: ToolKind) -> ToolConfirmPolicy {
        switch kind {
        case .read: return settings.readPolicy
        case .write: return settings.writePolicy
        case .delete: return settings.deletePolicy
        }
    }

    private func currentConfig() -> LLMConfig {
        let url = URL(string: settings.ollamaBaseURL) ?? URL(string: "http://localhost:11434")!
        let reasoning = (capabilityStore?.hasThinking ?? false) ? settings.reasoningLevel : .off
        return LLMConfig(
            provider: settings.provider,
            baseURL: url,
            model: settings.ollamaModel,
            temperature: settings.temperature,
            reasoning: reasoning
        )
    }

    private func escapeJSON(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

struct ToolConfirmRequest: Identifiable, Equatable {
    let id: UUID
    let call: LLMToolCall
    let kind: ToolKind
}
