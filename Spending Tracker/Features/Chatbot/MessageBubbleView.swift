import SwiftUI
import AppKit

struct MessageBubbleView: View {
    let message: LLMMessage
    var toolResults: [String: LLMMessage] = [:]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                roleLabel
                if let images = message.images, !images.isEmpty {
                    imagesView(images)
                }
                if let ocrTexts = message.ocrTexts, ocrTexts.contains(where: { !$0.isEmpty }) {
                    OCRDisclosure(ocrTexts: ocrTexts)
                }
                contentView
                if let calls = message.toolCalls, !calls.isEmpty {
                    ToolCallsDisclosure(calls: calls, results: toolResults)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatar: some View {
        ZStack {
            Circle().fill(bubbleColor.opacity(0.25)).frame(width: 28, height: 28)
            Image(systemName: avatarSymbol)
                .foregroundStyle(bubbleColor)
        }
    }

    private var roleLabel: some View {
        Text(roleTitle)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func imagesView(_ images: [String]) -> some View {
        let nsImages = images.compactMap { Data(base64Encoded: $0).flatMap { NSImage(data: $0) } }
        if !nsImages.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(nsImages.enumerated()), id: \.offset) { _, img in
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.role {
        case .tool:
            EmptyView()
        case .assistant:
            assistantContent
        case .user:
            Text(message.content)
                .textSelection(.enabled)
        case .system:
            Text(message.content)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var assistantContent: some View {
        let parts = ThinkingParser.parse(message.content)
        VStack(alignment: .leading, spacing: 6) {
            if parts.hasThinking {
                ThinkingDisclosure(blocks: parts.blocks, streaming: parts.streaming)
            }
            if !parts.answer.isEmpty {
                MarkdownRenderer(text: parts.answer)
            }
        }
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user: return .accentColor
        case .assistant: return .purple
        case .tool: return .orange
        case .system: return .secondary
        }
    }

    private var avatarSymbol: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "brain.head.profile"
        case .tool: return "wrench.and.screwdriver"
        case .system: return "gear"
        }
    }

    private var roleTitle: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "Assistant"
        case .tool: return "Tool result"
        case .system: return "System"
        }
    }
}

#if DEBUG
#Preview("User message") {
    MessageBubbleView(message: LLMMessage(
        role: .user,
        content: "Add ₹250 for lunch paid by UPI"
    ))
    .padding()
}

#Preview("Assistant message") {
    MessageBubbleView(message: LLMMessage(
        role: .assistant,
        content: "I've added a ₹250.00 expense for lunch, categorized as **Food** and paid via **UPI**."
    ))
    .padding()
}

#Preview("Assistant with tool call") {
    MessageBubbleView(message: LLMMessage(
        role: .assistant,
        content: "Let me add that transaction for you.",
        toolCalls: [LLMToolCall(id: "1", name: "add_transaction",
                                arguments: .object([
                                    "amount": .number(250),
                                    "type": .string("expense"),
                                    "category": .string("Food"),
                                    "payment_method": .string("UPI")
                                ]))]
    ))
    .padding()
}
#endif
