import SwiftUI

struct OCRDisclosure: View {
    let ocrTexts: [String]

    @State private var isExpanded = false

    private var nonEmptyCount: Int {
        ocrTexts.filter { !$0.isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "text.viewfinder")
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
                .background(Capsule().fill(.background.tertiary))
                .overlay(Capsule().stroke(.separator.opacity(0.5), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("Show text extracted from attached images")

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(ocrTexts.enumerated()), id: \.offset) { i, text in
                        if !text.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ocrTexts.count > 1 ? "Image \(i + 1)" : "Image")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Text(text)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.background.secondary))
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
        nonEmptyCount == 1 ? "OCR text from image" : "OCR text from \(nonEmptyCount) images"
    }
}
