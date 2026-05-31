import SwiftUI

struct ChatView: View {
    @State var service: ChatService
    @State private var draft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(service.messages.enumerated()), id: \.offset) { idx, msg in
                            if msg.role != .system {
                                MessageBubbleView(message: msg)
                                    .id(idx)
                            }
                        }
                        if !service.streamingAssistantText.isEmpty {
                            MessageBubbleView(message: LLMMessage(
                                role: .assistant,
                                content: service.streamingAssistantText
                            ))
                            .id("streaming")
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
                .onChange(of: service.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(service.messages.count - 1, anchor: .bottom) }
                }
                .onChange(of: service.streamingAssistantText) { _, _ in
                    proxy.scrollTo("streaming", anchor: .bottom)
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
            ToolbarItem {
                Button("New Chat") { service.reset() }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom) {
            TextEditor(text: $draft)
                .font(.body)
                .frame(minHeight: 40, maxHeight: 120)
                .padding(6)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
            Button {
                let toSend = draft
                draft = ""
                Task { await service.send(userText: toSend) }
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(service.isBusy || draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(8)
    }
}
