import SwiftUI
import Charts

struct SummaryCardWidget: View {
    let summary: DashboardSummary

    var body: some View {
        WidgetCard(title: "This Month") {
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Expense").font(.caption).foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(summary.totalExpense))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.red)
                }
                VStack(alignment: .leading) {
                    Text("Income").font(.caption).foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(summary.totalIncome))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading) {
                    Text("Net").font(.caption).foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(summary.net))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(summary.net >= 0 ? .green : .red)
                }
            }
        }
    }
}

struct SpendingTrendWidget: View {
    let data: [DailySpend]

    var body: some View {
        WidgetCard(title: "Spending — Last 30 Days") {
            if data.isEmpty {
                Text("No data").foregroundStyle(.secondary)
            } else {
                Chart(data) { d in
                    BarMark(
                        x: .value("Day", d.date, unit: .day),
                        y: .value("Total", NSDecimalNumber(decimal: d.total).doubleValue)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: 160)
            }
        }
    }
}

struct TopCategoriesWidget: View {
    let breakdown: [CategoryBreakdown]

    var body: some View {
        WidgetCard(title: "Top Categories") {
            if breakdown.isEmpty {
                Text("No expenses yet").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(breakdown) { item in
                        HStack {
                            Circle().fill(Color(hex: item.colorHex)).frame(width: 10, height: 10)
                            Text(item.categoryName)
                            Spacer()
                            Text(CurrencyFormatter.format(item.total)).monospacedDigit()
                            Text("\(Int(item.percent * 100))%").foregroundStyle(.secondary).monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }
}

struct BudgetBurnDownWidget: View {
    let statuses: [BudgetStatus]

    var body: some View {
        WidgetCard(title: "Budget Burn-Down") {
            if statuses.isEmpty {
                Text("No budgets set").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(statuses) { st in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(st.categoryName).font(.subheadline)
                                Spacer()
                                Text("\(Int(st.percent * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: min(st.percent, 1.0))
                                .tint(color(for: st.percent))
                        }
                    }
                }
            }
        }
    }

    private func color(for p: Double) -> Color {
        switch p {
        case ..<0.7: return .green
        case ..<1.0: return .orange
        default: return .red
        }
    }
}

struct PaymentMethodBreakdownWidget: View {
    let data: [PMBreakdown]

    var body: some View {
        WidgetCard(title: "Payment Methods") {
            if data.isEmpty {
                Text("No data").foregroundStyle(.secondary)
            } else {
                Chart(data) { d in
                    BarMark(
                        x: .value("Total", NSDecimalNumber(decimal: d.total).doubleValue),
                        y: .value("Method", d.name)
                    )
                    .foregroundStyle(by: .value("Method", d.name))
                }
                .frame(height: max(CGFloat(data.count) * 24, 80))
            }
        }
    }
}

struct RecentTransactionsWidget: View {
    let txs: [Transaction]
    let onTap: (Transaction) -> Void

    var body: some View {
        WidgetCard(title: "Recent") {
            if txs.isEmpty {
                Text("No transactions").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(txs, id: \.id) { tx in
                        TransactionRowView(transaction: tx)
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(tx) }
                    }
                }
            }
        }
    }
}

struct LargestTransactionWidget: View {
    let tx: Transaction?

    var body: some View {
        WidgetCard(title: "Largest Expense (Month)") {
            if let tx {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CurrencyFormatter.format(tx.amount))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.red)
                    Text(tx.note.isEmpty ? (tx.category?.name ?? "—") : tx.note)
                        .font(.subheadline)
                    Text(tx.date, style: .date).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("No expenses").foregroundStyle(.secondary)
            }
        }
    }
}

struct CompareLastMonthWidget: View {
    let deltas: [CategoryDelta]

    var body: some View {
        WidgetCard(title: "vs Last Month") {
            if deltas.isEmpty {
                Text("Not enough data").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(deltas) { d in
                        HStack {
                            Text(d.categoryName).font(.subheadline)
                            Spacer()
                            Text(CurrencyFormatter.format(d.thisMonth)).monospacedDigit().font(.caption)
                            Image(systemName: d.deltaPercent >= 0 ? "arrow.up" : "arrow.down")
                                .foregroundStyle(d.deltaPercent >= 0 ? .red : .green)
                            Text("\(Int(abs(d.deltaPercent) * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(d.deltaPercent >= 0 ? .red : .green)
                                .font(.caption.bold())
                        }
                    }
                }
            }
        }
    }
}

struct WidgetCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}
