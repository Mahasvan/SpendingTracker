import SwiftUI

struct MessageBubbleView: View {
    let message: LLMMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                roleLabel
                contentView
                if let calls = message.toolCalls, !calls.isEmpty {
                    toolCallsBadge(calls)
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
    private var contentView: some View {
        switch message.role {
        case .tool:
            VStack(alignment: .leading, spacing: 4) {
                Label("Tool: \(message.name ?? "?")", systemImage: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(message.content)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
            }
        case .assistant:
            MarkdownRenderer(text: message.content.isEmpty ? "_…_" : message.content)
        case .user:
            Text(message.content)
                .textSelection(.enabled)
        case .system:
            Text(message.content)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func toolCallsBadge(_ calls: [LLMToolCall]) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver.fill").font(.caption2)
            Text("Calls: \(calls.map(\.name).joined(separator: ", "))")
                .font(.caption2)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(.background.tertiary, in: Capsule())
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
