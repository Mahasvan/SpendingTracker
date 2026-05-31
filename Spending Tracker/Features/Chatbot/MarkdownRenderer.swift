import SwiftUI

struct MarkdownRenderer: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks(text).enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: MDBlock) -> some View {
        switch block {
        case .heading(let level, let content):
            Text(inlineMarkdown(content))
                .font(headingFont(level))
                .bold()
        case .codeBlock(let lang, let code):
            CodeBlockView(language: lang, code: code)
        case .paragraph(let body):
            Text(inlineMarkdown(body))
                .textSelection(.enabled)
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        Text(inlineMarkdown(item)).textSelection(.enabled)
                    }
                }
            }
        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(idx + 1).")
                        Text(inlineMarkdown(item)).textSelection(.enabled)
                    }
                }
            }
        case .blockquote(let content):
            HStack(spacing: 8) {
                Rectangle().fill(Color.secondary).frame(width: 3)
                Text(inlineMarkdown(content)).foregroundStyle(.secondary)
            }
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        default: return .headline
        }
    }

    private func inlineMarkdown(_ s: String) -> AttributedString {
        if let a = try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return a
        }
        return AttributedString(s)
    }
}

private enum MDBlock {
    case heading(Int, String)
    case codeBlock(language: String, code: String)
    case paragraph(String)
    case bulletList([String])
    case numberedList([String])
    case blockquote(String)
}

private struct CodeBlockView: View {
    let language: String
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !language.isEmpty {
                Text(language)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
            .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private func parseBlocks(_ text: String) -> [MDBlock] {
    var blocks: [MDBlock] = []
    let lines = text.components(separatedBy: "\n")
    var i = 0
    while i < lines.count {
        let line = lines[i]
        if line.hasPrefix("```") {
            let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            var bodyLines: [String] = []
            i += 1
            while i < lines.count, !lines[i].hasPrefix("```") {
                bodyLines.append(lines[i])
                i += 1
            }
            if i < lines.count { i += 1 } // skip closing fence
            blocks.append(.codeBlock(language: language, code: bodyLines.joined(separator: "\n")))
            continue
        }
        if let h = parseHeading(line) {
            blocks.append(.heading(h.level, h.text))
            i += 1
            continue
        }
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("> ") {
            var buf: [String] = []
            while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("> ") {
                buf.append(String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst(2)))
                i += 1
            }
            blocks.append(.blockquote(buf.joined(separator: " ")))
            continue
        }
        if isBullet(line) {
            var items: [String] = []
            while i < lines.count, isBullet(lines[i]) {
                items.append(stripBullet(lines[i]))
                i += 1
            }
            blocks.append(.bulletList(items))
            continue
        }
        if isNumbered(line) {
            var items: [String] = []
            while i < lines.count, isNumbered(lines[i]) {
                items.append(stripNumbered(lines[i]))
                i += 1
            }
            blocks.append(.numberedList(items))
            continue
        }
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            i += 1
            continue
        }
        var buf: [String] = [line]
        i += 1
        while i < lines.count,
              !lines[i].trimmingCharacters(in: .whitespaces).isEmpty,
              !lines[i].hasPrefix("```"),
              parseHeading(lines[i]) == nil,
              !isBullet(lines[i]),
              !isNumbered(lines[i]),
              !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("> ") {
            buf.append(lines[i])
            i += 1
        }
        blocks.append(.paragraph(buf.joined(separator: " ")))
    }
    return blocks
}

private func parseHeading(_ line: String) -> (level: Int, text: String)? {
    let t = line.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("### ") { return (3, String(t.dropFirst(4))) }
    if t.hasPrefix("## ") { return (2, String(t.dropFirst(3))) }
    if t.hasPrefix("# ") { return (1, String(t.dropFirst(2))) }
    return nil
}

private func isBullet(_ line: String) -> Bool {
    let t = line.trimmingCharacters(in: .whitespaces)
    return t.hasPrefix("- ") || t.hasPrefix("* ")
}
private func stripBullet(_ line: String) -> String {
    let t = line.trimmingCharacters(in: .whitespaces)
    return String(t.dropFirst(2))
}
private func isNumbered(_ line: String) -> Bool {
    let t = line.trimmingCharacters(in: .whitespaces)
    guard let firstSpace = t.firstIndex(of: " ") else { return false }
    let prefix = t[..<firstSpace]
    return prefix.hasSuffix(".") && prefix.dropLast().allSatisfy(\.isNumber)
}
private func stripNumbered(_ line: String) -> String {
    let t = line.trimmingCharacters(in: .whitespaces)
    if let firstSpace = t.firstIndex(of: " ") {
        return String(t[t.index(after: firstSpace)...])
    }
    return t
}
