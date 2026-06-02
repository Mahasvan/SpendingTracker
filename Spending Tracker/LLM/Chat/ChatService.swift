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
    You are an assistant inside a personal spending tracker app. The user manages \
    transactions in INR (Indian Rupees). Use the provided tools to read or modify data \
    instead of guessing. When showing money, format as ₹ with two decimals. Be concise.
    When the user asks to add, update, or delete a transaction, call the appropriate tool. \
    Never invent transaction ids — fetch them with list_transactions or search_transactions first.

    Dates and times:
    - When the user refers to a relative or partial date/time ("today", "yesterday", \
    "now", "this morning", "last Friday", "3pm"), call get_current_datetime first to anchor \
    the current local date, time, and UTC offset, then compute the concrete ISO-8601 value.
    - Always pass the date to add_transaction/update_transaction when the user gives one, and \
    include the time component whenever the user specifies or clearly implies a time \
    (e.g. "2026-06-02T15:30"). If only a date is known, a date is fine. If no date is given, \
    omit it so it defaults to now.

    Categorizing transactions:
    - Before adding (or updating) a transaction, first call get_categories to see the \
    categories that already exist, then choose the single most appropriate existing \
    category for the transaction based on its note/description. Pass that category name \
    to add_transaction.
    - For income transactions, default the category to "Salary" and the payment method to \
    a bank-transfer method (e.g. "Bank Transfer") when the user does not specify otherwise. \
    You may also call get_payment_methods to confirm the exact available names.
    - Prefer not to leave a transaction without a category. Only skip the category when none \
    of the existing categories reasonably fits and the user has not given enough detail.
    - Category and payment method are OPTIONAL. If nothing fits, or the user explicitly does \
    not want one, add the transaction without them rather than blocking, guessing, or \
    inventing a category. Do not create new categories unless the user asks you to.

    Today's date for context: \(ISO8601DateFormatter.shared.string(from: .now)).
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
