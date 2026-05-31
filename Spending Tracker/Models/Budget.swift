import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID = UUID()
    var amount: Decimal = Decimal.zero
    var periodRaw: String = BudgetPeriod.monthly.rawValue
    var startDate: Date = Date.now
    var createdAt: Date = Date.now

    var category: Category?

    var period: BudgetPeriod {
        get { BudgetPeriod(rawValue: periodRaw) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Decimal,
        period: BudgetPeriod = .monthly,
        startDate: Date = .now,
        category: Category? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.periodRaw = period.rawValue
        self.startDate = startDate
        self.category = category
        self.createdAt = createdAt
    }
}
