import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID = UUID()
    var amount: Decimal = Decimal.zero
    var typeRaw: String = TxType.expense.rawValue
    var date: Date = Date.now
    var note: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var category: Category?
    var paymentMethod: PaymentMethod?

    var type: TxType {
        get { TxType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TxType = .expense,
        date: Date = .now,
        note: String = "",
        category: Category? = nil,
        paymentMethod: PaymentMethod? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.typeRaw = type.rawValue
        self.date = date
        self.note = note
        self.category = category
        self.paymentMethod = paymentMethod
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var signedAmount: Decimal {
        switch type {
        case .expense: return -amount
        case .income: return amount
        }
    }
}
