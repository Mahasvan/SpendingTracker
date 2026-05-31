import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

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
