import SwiftUI

struct ToolConfirmView: View {
    let request: ToolConfirmRequest
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text("Approve tool call?")
                    .font(.headline)
            }
            Text("\(request.call.name)")
                .font(.subheadline.monospaced())
            ScrollView {
                Text(request.call.arguments.toString())
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 6))
            }
            .frame(maxHeight: 200)
            HStack {
                Spacer()
                Button("Reject", role: .destructive, action: onReject)
                Button("Approve") { onApprove() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.5), lineWidth: 1)
        )
    }

    private var icon: String {
        switch request.kind {
        case .read: return "eye"
        case .write: return "pencil"
        case .delete: return "trash"
        }
    }

    private var color: Color {
        switch request.kind {
        case .read: return .blue
        case .write: return .orange
        case .delete: return .red
        }
    }
}
