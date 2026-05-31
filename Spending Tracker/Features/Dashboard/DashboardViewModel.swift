import Foundation
import Observation

struct DashboardSummary: Sendable {
    var totalExpense: Decimal = 0
    var totalIncome: Decimal = 0
    var net: Decimal { totalIncome - totalExpense }
    var largestExpense: Transaction?
}

struct CategoryBreakdown: Identifiable, Sendable {
    let id = UUID()
    let categoryName: String
    let colorHex: String
    let total: Decimal
    let percent: Double
}

struct PMBreakdown: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let kind: PMKind
    let total: Decimal
}

struct DailySpend: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let total: Decimal
}

struct CategoryDelta: Identifiable, Sendable {
    let id = UUID()
    let categoryName: String
    let thisMonth: Decimal
    let lastMonth: Decimal
    var deltaPercent: Double {
        guard lastMonth > 0 else { return thisMonth > 0 ? 1.0 : 0 }
        let dec = (thisMonth - lastMonth) as NSDecimalNumber
        let lm = lastMonth as NSDecimalNumber
        return dec.doubleValue / lm.doubleValue
    }
}

@MainActor
@Observable
final class DashboardViewModel {
    private let txRepo: any TransactionRepository
    private let budgetsVM: BudgetsViewModel

    var summary = DashboardSummary()
    var topCategories: [CategoryBreakdown] = []
    var pmBreakdown: [PMBreakdown] = []
    var dailySpend: [DailySpend] = []
    var recent: [Transaction] = []
    var compareLastMonth: [CategoryDelta] = []
    var errorMessage: String?

    init(txRepo: any TransactionRepository, budgetsVM: BudgetsViewModel) {
        self.txRepo = txRepo
        self.budgetsVM = budgetsVM
    }

    var budgetStatuses: [BudgetStatus] { budgetsVM.statuses }

    func load() {
        do {
            let thisMonth = DateRange.thisMonth
            let lastMonth = DateRange.lastMonth

            var qThis = TransactionQuery()
            qThis.dateFrom = thisMonth.start
            qThis.dateTo = thisMonth.end
            let txsThis = try txRepo.fetch(qThis)

            var qLast = TransactionQuery()
            qLast.dateFrom = lastMonth.start
            qLast.dateTo = lastMonth.end
            let txsLast = try txRepo.fetch(qLast)

            var s = DashboardSummary()
            for tx in txsThis {
                switch tx.type {
                case .expense: s.totalExpense += tx.amount
                case .income: s.totalIncome += tx.amount
                }
            }
            s.largestExpense = txsThis
                .filter { $0.type == .expense }
                .max(by: { $0.amount < $1.amount })
            summary = s

            topCategories = computeCategoryBreakdown(txsThis)
            pmBreakdown = computePMBreakdown(txsThis)
            dailySpend = computeDailySpend(window: DateRange.last30Days)
            recent = Array(txsThis.sorted { $0.date > $1.date }.prefix(5))
            compareLastMonth = computeCompare(this: txsThis, last: txsLast)

            budgetsVM.load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func computeCategoryBreakdown(_ txs: [Transaction]) -> [CategoryBreakdown] {
        let expenses = txs.filter { $0.type == .expense }
        var totalByCat: [UUID: (name: String, color: String, total: Decimal)] = [:]
        for tx in expenses {
            guard let cat = tx.category else { continue }
            var entry = totalByCat[cat.id] ?? (cat.name, cat.colorHex, 0)
            entry.total += tx.amount
            totalByCat[cat.id] = entry
        }
        let total = expenses.reduce(Decimal.zero) { $0 + $1.amount }
        let totalD = NSDecimalNumber(decimal: total).doubleValue
        return totalByCat
            .map { (_, v) in
                CategoryBreakdown(
                    categoryName: v.name,
                    colorHex: v.color,
                    total: v.total,
                    percent: totalD == 0 ? 0 : NSDecimalNumber(decimal: v.total).doubleValue / totalD
                )
            }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }
    }

    private func computePMBreakdown(_ txs: [Transaction]) -> [PMBreakdown] {
        let expenses = txs.filter { $0.type == .expense }
        var totals: [UUID: (name: String, kind: PMKind, total: Decimal)] = [:]
        for tx in expenses {
            guard let pm = tx.paymentMethod else { continue }
            var entry = totals[pm.id] ?? (pm.name, pm.kind, 0)
            entry.total += tx.amount
            totals[pm.id] = entry
        }
        return totals
            .map { (_, v) in PMBreakdown(name: v.name, kind: v.kind, total: v.total) }
            .sorted { $0.total > $1.total }
    }

    private func computeDailySpend(window: DateRange) -> [DailySpend] {
        var q = TransactionQuery()
        q.dateFrom = window.start
        q.dateTo = window.end
        q.type = .expense
        let txs = (try? txRepo.fetch(q)) ?? []
        let cal = Calendar.current
        var bucket: [Date: Decimal] = [:]
        for tx in txs {
            let day = cal.startOfDay(for: tx.date)
            bucket[day, default: 0] += tx.amount
        }
        return bucket
            .map { DailySpend(date: $0.key, total: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func computeCompare(this: [Transaction], last: [Transaction]) -> [CategoryDelta] {
        func totalsByCategory(_ txs: [Transaction]) -> [UUID: (name: String, total: Decimal)] {
            var out: [UUID: (name: String, total: Decimal)] = [:]
            for tx in txs where tx.type == .expense {
                guard let cat = tx.category else { continue }
                var entry = out[cat.id] ?? (cat.name, 0)
                entry.total += tx.amount
                out[cat.id] = entry
            }
            return out
        }
        let thisT = totalsByCategory(this)
        let lastT = totalsByCategory(last)
        let keys = Set(thisT.keys).union(lastT.keys)
        return keys.compactMap { id -> CategoryDelta? in
            let name = thisT[id]?.name ?? lastT[id]?.name ?? "?"
            return CategoryDelta(
                categoryName: name,
                thisMonth: thisT[id]?.total ?? 0,
                lastMonth: lastT[id]?.total ?? 0
            )
        }
        .sorted { abs($0.deltaPercent) > abs($1.deltaPercent) }
        .prefix(5)
        .map { $0 }
    }
}
