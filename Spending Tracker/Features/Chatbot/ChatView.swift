import SwiftUI

struct ChatView: View {
    @State var service: ChatService
    @Bindable var settings: AppSettings
    @State private var draft: String = ""
    @State private var showSettings = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    if isEmptyState {
                        ChatSuggestionsView(suggestions: ChatSuggestion.defaults) { s in
                            handleSuggestion(s)
                        }
                        .frame(minHeight: 420)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            let results = toolResultsMap()
                            ForEach(Array(visibleMessages().enumerated()), id: \.offset) { idx, msg in
                                MessageBubbleView(message: msg, toolResults: results)
                                    .id(idx)
                            }
                            if !service.streamingAssistantText.isEmpty {
                                MessageBubbleView(message: LLMMessage(
                                    role: .assistant,
                                    content: service.streamingAssistantText
                                ))
                                .id("streaming")
                            }
                            if showTypingIndicator {
                                TypingIndicator().id("typing")
                            }
                            if let confirm = service.pendingConfirmation {
                                ToolConfirmView(
                                    request: confirm,
                                    onApprove: { Task { await service.approve(confirm) } },
                                    onReject: { Task { await service.reject(confirm) } }
                                )
                                .id("confirm")
                            }
                        }
                        .padding()
                    }
                }
                .onChange(of: service.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(service.messages.count - 1, anchor: .bottom) }
                }
                .onChange(of: service.streamingAssistantText) { _, _ in
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
                .onChange(of: service.isBusy) { _, busy in
                    if busy { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                }
            }
            Divider()
            inputBar
            if let err = service.errorMessage {
                Text(err).foregroundStyle(.red).padding(8)
            }
        }
        .navigationTitle("Chatbot")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    service.reset()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .help("Start a fresh chat (clears the conversation)")
                Button {
                    showSettings = true
                } label: {
                    Label("Chat Settings", systemImage: "gearshape")
                }
                .help("Configure LLM provider, model, and tool permissions")
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                LLMSettingsView(settings: settings)
                    .navigationTitle("Chat Settings")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                                .help("Close chat settings")
                        }
                    }
            }
            .frame(minWidth: 480, minHeight: 420)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .font(.body)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(.background.secondary)
                )
                .overlay(
                    Capsule().stroke(.separator, lineWidth: 0.5)
                )
                .onSubmit(sendDraft)

            Button(action: sendDraft) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(canSend ? Color.accentColor : Color.secondary.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(!canSend)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var canSend: Bool {
        !service.isBusy && !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func sendDraft() {
        guard canSend else { return }
        let toSend = draft
        draft = ""
        Task { await service.send(userText: toSend) }
    }

    private var showTypingIndicator: Bool {
        service.isBusy
            && service.streamingAssistantText.isEmpty
            && service.pendingConfirmation == nil
    }

    private func visibleMessages() -> [LLMMessage] {
        service.messages.filter { $0.role != .system && $0.role != .tool }
    }

    private var isEmptyState: Bool {
        visibleMessages().isEmpty
            && service.streamingAssistantText.isEmpty
            && service.pendingConfirmation == nil
            && !service.isBusy
    }

    private func handleSuggestion(_ s: ChatSuggestion) {
        draft = s.prompt
        inputFocused = true
    }

    private func toolResultsMap() -> [String: LLMMessage] {
        var map: [String: LLMMessage] = [:]
        for msg in service.messages where msg.role == .tool {
            if let id = msg.toolCallId { map[id] = msg }
        }
        return map
    }
}
