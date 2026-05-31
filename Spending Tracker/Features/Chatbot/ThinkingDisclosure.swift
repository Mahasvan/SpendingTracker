import SwiftUI

struct ThinkingParts {
    var blocks: [String]
    var answer: String
    var streaming: Bool

    var hasThinking: Bool { !blocks.isEmpty || streaming }
}

enum ThinkingParser {
    private static let tagPairs: [(open: String, close: String)] = [
        ("<think>", "</think>"),
        ("<thinking>", "</thinking>"),
        ("<reasoning>", "</reasoning>"),
        ("<reflection>", "</reflection>")
    ]

    static func parse(_ content: String) -> ThinkingParts {
        var remaining = content
        var blocks: [String] = []
        var answerParts: [String] = []
        var streaming = false

        outer: while !remaining.isEmpty {
            guard let nextOpen = nextOpenTag(in: remaining) else {
                answerParts.append(remaining)
                break outer
            }

            let prefix = String(remaining[remaining.startIndex..<nextOpen.range.lowerBound])
            if !prefix.isEmpty {
                answerParts.append(prefix)
            }

            let afterOpen = nextOpen.range.upperBound
            let searchTail = remaining[afterOpen...]
            if let closeRange = searchTail.range(of: nextOpen.close, options: .caseInsensitive) {
                let block = String(remaining[afterOpen..<closeRange.lowerBound])
                blocks.append(block.trimmingCharacters(in: .whitespacesAndNewlines))
                remaining = String(remaining[closeRange.upperBound...])
            } else {
                let partial = String(remaining[afterOpen...])
                blocks.append(partial.trimmingCharacters(in: .whitespacesAndNewlines))
                streaming = true
                break outer
            }
        }

        let answer = answerParts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return ThinkingParts(blocks: blocks, answer: answer, streaming: streaming)
    }

    private struct TagHit {
        let range: Range<String.Index>
        let close: String
    }

    private static func nextOpenTag(in s: String) -> TagHit? {
        var best: TagHit?
        for pair in tagPairs {
            if let r = s.range(of: pair.open, options: .caseInsensitive) {
                if best == nil || r.lowerBound < best!.range.lowerBound {
                    best = TagHit(range: r, close: pair.close)
                }
            }
        }
        return best
    }
}

struct ThinkingDisclosure: View {
    let blocks: [String]
    let streaming: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
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
            .help(streaming ? "Model is thinking…" : "Show the model's reasoning")

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        if !block.isEmpty {
                            Text(block)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8).fill(.background.secondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.separator.opacity(0.4), lineWidth: 0.5)
                                )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var headerText: String {
        if streaming {
            return "Thinking…"
        }
        if blocks.count == 1 {
            return "Thought for a moment"
        }
        return "Thought in \(blocks.count) steps"
    }
}
