import Foundation
import Observation

struct BudgetStatus: Identifiable, Sendable {
    let id: UUID
    let categoryId: UUID
    let categoryName: String
    let categoryColor: String
    let limit: Decimal
    let spent: Decimal
    var remaining: Decimal { limit - spent }
    var percent: Double {
        guard limit > 0 else { return 0 }
        let p = (NSDecimalNumber(decimal: spent).doubleValue) / NSDecimalNumber(decimal: limit).doubleValue
        return max(0, min(p, 2))
    }
}

enum BudgetRangeSelection: Equatable {
    case thisMonth
    case lastMonth
    case specificMonth(year: Int, month: Int)
    case custom(start: Date, end: Date)

    var displayLabel: String {
        switch self {
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        case .specificMonth(let y, let m):
            var comps = DateComponents()
            comps.year = y; comps.month = m
            if let d = Calendar.current.date(from: comps) {
                let f = DateFormatter()
                f.dateFormat = "LLLL yyyy"
                return f.string(from: d)
            }
            return "\(m)/\(y)"
        case .custom(let s, let e):
            let f = DateFormatter()
            f.dateStyle = .medium
            return "\(f.string(from: s)) – \(f.string(from: e))"
        }
    }

    func resolveRange() -> DateRange {
        let cal = Calendar.current
        switch self {
        case .thisMonth:
            return .thisMonth
        case .lastMonth:
            return .lastMonth
        case .specificMonth(let y, let m):
            var comps = DateComponents()
            comps.year = y; comps.month = m
            let start = cal.date(from: comps) ?? .now
            let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
            return DateRange(start: start, end: end)
        case .custom(let s, let e):
            return DateRange(start: s, end: e)
        }
    }
}

@MainActor
@Observable
final class BudgetsViewModel {
    private let repo: any BudgetRepository
    private let txRepo: any TransactionRepository
    private let categoryRepo: any CategoryRepository

    var budgets: [Budget] = []
    var statuses: [BudgetStatus] = []
    var categories: [Category] = []
    var errorMessage: String?
    var rangeSelection: BudgetRangeSelection = .thisMonth

    init(
        repo: any BudgetRepository,
        txRepo: any TransactionRepository,
        categoryRepo: any CategoryRepository
    ) {
        self.repo = repo
        self.txRepo = txRepo
        self.categoryRepo = categoryRepo
    }

    func setRange(_ selection: BudgetRangeSelection) {
        rangeSelection = selection
        load()
    }

    func load() {
        do {
            categories = try categoryRepo.all(includeArchived: false)
            budgets = try repo.all()
            statuses = computeStatuses()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addOrUpdate(categoryId: UUID, amount: Decimal) {
        do {
            if let existing = try repo.findByCategory(categoryId, period: .monthly) {
                existing.amount = amount
                try repo.update(existing)
            } else if let cat = try categoryRepo.find(id: categoryId) {
                try repo.add(Budget(amount: amount, period: .monthly, startDate: .now, category: cat))
            }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ b: Budget) {
        do {
            try repo.delete(id: b.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func computeStatuses() -> [BudgetStatus] {
        let range = rangeSelection.resolveRange()
        var q = TransactionQuery()
        q.dateFrom = range.start
        q.dateTo = range.end
        q.type = .expense
        let txs = (try? txRepo.fetch(q)) ?? []
        var spentPerCat: [UUID: Decimal] = [:]
        for tx in txs {
            guard let cid = tx.category?.id else { continue }
            spentPerCat[cid, default: 0] += tx.amount
        }
        return budgets.compactMap { b in
            guard let cat = b.category else { return nil }
            let spent = spentPerCat[cat.id] ?? 0
            return BudgetStatus(
                id: b.id,
                categoryId: cat.id,
                categoryName: cat.name,
                categoryColor: cat.colorHex,
                limit: b.amount,
                spent: spent
            )
        }
    }
}
