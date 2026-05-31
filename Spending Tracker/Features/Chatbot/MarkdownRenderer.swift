import SwiftUI
import MarkdownUI

struct MarkdownRenderer: View {
    let text: String

    var body: some View {
        Markdown(text)
            .markdownTheme(.chatBubble)
            .textSelection(.enabled)
    }
}

private extension Theme {
    static let chatBubble = Theme()
        .text {
            ForegroundColor(.primary)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.95))
            BackgroundColor(.codeInlineBackground)
        }
        .strong { FontWeight(.semibold) }
        .link { ForegroundColor(.accentColor) }
        .heading1 { config in
            VStack(alignment: .leading, spacing: 4) {
                config.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.6))
                    }
            }
            .padding(.vertical, 4)
        }
        .heading2 { config in
            config.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.35))
                }
                .padding(.top, 4)
        }
        .heading3 { config in
            config.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.15))
                }
        }
        .paragraph { config in
            config.label
                .relativeLineSpacing(.em(0.15))
                .markdownMargin(top: 0, bottom: 6)
        }
        .listItem { config in
            config.label.markdownMargin(top: 2, bottom: 2)
        }
        .blockquote { config in
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary)
                    .frame(width: 3)
                config.label
                    .markdownTextStyle { ForegroundColor(.secondary) }
            }
        }
        .codeBlock { config in
            VStack(alignment: .leading, spacing: 4) {
                if let lang = config.language, !lang.isEmpty {
                    Text(lang)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                ScrollView(.horizontal) {
                    config.label
                        .relativeLineSpacing(.em(0.15))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.95))
                        }
                        .padding(10)
                }
                .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 8))
            }
            .markdownMargin(top: 4, bottom: 4)
        }
        .table { config in
            config.label
                .markdownTableBorderStyle(.init(color: .tableBorder))
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.clear, Color.tableAltRow)
                )
                .markdownMargin(top: 4, bottom: 4)
        }
        .tableCell { config in
            config.label
                .markdownTextStyle {
                    if config.row == 0 { FontWeight(.semibold) }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
        }
}

private extension Color {
    static let codeInlineBackground = Color.secondary.opacity(0.18)
    static let tableBorder = Color.secondary.opacity(0.35)
    static let tableAltRow = Color.secondary.opacity(0.08)
}
