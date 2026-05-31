import SwiftUI

struct ToolCallsDisclosure: View {
    let calls: [LLMToolCall]
    let results: [String: LLMMessage]

    @State private var isExpanded = false
    @State private var expandedCallIds: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.caption2)
                    Text(headerText)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(.background.tertiary)
                )
                .overlay(
                    Capsule().stroke(.separator.opacity(0.5), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(calls) { call in
                        callRow(call)
                    }
                }
                .padding(.leading, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var headerText: String {
        if calls.count == 1 {
            return "Used tool: \(calls[0].name)"
        }
        return "Used \(calls.count) tools: \(calls.map(\.name).joined(separator: ", "))"
    }

    @ViewBuilder
    private func callRow(_ call: LLMToolCall) -> some View {
        let expanded = expandedCallIds.contains(call.id)
        let result = results[call.id]

        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expanded { expandedCallIds.remove(call.id) }
                    else { expandedCallIds.insert(call.id) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Text(call.name)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                    if let resultStatus = statusLabel(for: result) {
                        Text(resultStatus.0)
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(resultStatus.1.opacity(0.15), in: Capsule())
                            .foregroundStyle(resultStatus.1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    detailRow(title: "Arguments", text: prettyJSON(call.arguments))
                    if let result {
                        detailRow(title: "Result", text: prettyResult(result.content))
                    } else {
                        Text("No result recorded.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 14)
                .transition(.opacity)
            }
        }
    }

    private func detailRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func statusLabel(for result: LLMMessage?) -> (String, Color)? {
        guard let result else { return ("pending", .orange) }
        if result.content.contains("\"error\"") { return ("error", .red) }
        return ("ok", .green)
    }

    private func prettyJSON(_ v: JSONValue) -> String {
        let s = v.toString()
        guard let data = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return s
        }
        return str
    }

    private func prettyResult(_ s: String) -> String {
        guard let data = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return s
        }
        return str
    }
}
