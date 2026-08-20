import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    var onCategorize: ((Transaction) async -> Void)?

    @State private var isCategorizing = false

    var body: some View {
        HStack(spacing: 12) {
            categoryIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.note.isEmpty ? (transaction.category?.name ?? "Uncategorized") : transaction.note)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let cat = transaction.category {
                        Text(cat.name).font(.caption).foregroundStyle(.secondary)
                    }
                    if transaction.category != nil, transaction.paymentMethod != nil {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                    }
                    if let pm = transaction.paymentMethod {
                        Image(systemName: pm.kind.systemImage).font(.caption2)
                        Text(pm.name).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if transaction.category == nil, onCategorize != nil {
                categorizeButton
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.formatSigned(transaction.amount, type: transaction.type))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(transaction.type == .income ? Color.green : Color.primary)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        // Stop the spinner the moment the category is assigned.
        .onChange(of: transaction.category) { _, _ in
            isCategorizing = false
        }
    }

    private var categorizeButton: some View {
        // Solid rounded-rectangle button with the Apple Intelligence glyph +
        // "Categorize" label. Tapping triggers on-device categorization for
        // this single transaction. Shows a spinner until the category is set.
        Button {
            isCategorizing = true
            Task { await onCategorize?(transaction) }
        } label: {
            HStack(spacing: 4) {
                if isCategorizing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "apple.intelligence")
                        .font(.subheadline)
                }
                Text(isCategorizing ? "Categorizing…" : "Categorize")
                    .font(.caption)
            }
            .padding(8)
            .frame(maxHeight: .infinity)
            .buttonStyle(.glassProminent)
            .background(.regularMaterial)
            .foregroundStyle(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isCategorizing)
        .fixedSize()
        .help("Categorize with Apple Intelligence")
    }

    private var categoryIcon: some View {
        let color = Color(hex: transaction.category?.colorHex ?? "#888888")
        return ZStack {
            Circle().fill(color.opacity(0.2)).frame(width: 32, height: 32)
            Image(systemName: transaction.category?.systemImage ?? "tag")
                .foregroundStyle(color)
        }
    }
}

#if DEBUG
#Preview("Categorized") {
    let cat = PreviewSupport.sampleCategory()
    let pm = PreviewSupport.samplePaymentMethod()
    let tx = PreviewSupport.sampleTransaction(category: cat, paymentMethod: pm)
    TransactionRowView(transaction: tx)
        .padding()
}

#Preview("Uncategorized — with categorize button") {
    let pm = PreviewSupport.samplePaymentMethod()
    let tx = PreviewSupport.sampleTransaction(note: "Unknown charge", category: nil, paymentMethod: pm)
    TransactionRowView(transaction: tx) { _ in }
        .padding()
}

#Preview("Uncategorized — no callback") {
    let tx = PreviewSupport.sampleTransaction(note: "Cash payment", category: nil, paymentMethod: nil)
    TransactionRowView(transaction: tx)
        .padding()
}

#Preview("Income") {
    let cat = PreviewSupport.sampleCategory(name: "Salary", color: "#AED581", icon: "indianrupeesign.circle")
    let pm = PreviewSupport.samplePaymentMethod(name: "Bank Transfer", kind: .bankTransfer)
    let tx = PreviewSupport.sampleTransaction(note: "Monthly salary", amount: 50000, type: .income,
                                              category: cat, paymentMethod: pm)
    TransactionRowView(transaction: tx)
        .padding()
}
#endif
