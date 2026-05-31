import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#888888"
    var systemImage: String = "tag"
    var archived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget]? = []

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#888888",
        systemImage: String = "tag",
        archived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.systemImage = systemImage
        self.archived = archived
        self.createdAt = createdAt
    }
}
