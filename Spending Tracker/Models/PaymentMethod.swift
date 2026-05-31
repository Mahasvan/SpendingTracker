import Foundation
import SwiftData

@Model
final class PaymentMethod {
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = PMKind.other.rawValue
    var archived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Transaction.paymentMethod)
    var transactions: [Transaction]? = []

    var kind: PMKind {
        get { PMKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        kind: PMKind = .other,
        archived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.archived = archived
        self.createdAt = createdAt
    }
}
