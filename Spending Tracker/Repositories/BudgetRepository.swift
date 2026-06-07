import Foundation
import SwiftData

@MainActor
protocol BudgetRepository: AnyObject {
    func add(_ b: Budget) throws
    func update(_ b: Budget) throws
    func delete(id: UUID) throws
    func find(id: UUID) throws -> Budget?
    func findByCategory(_ categoryId: UUID, period: BudgetPeriod) throws -> Budget?
    func all() throws -> [Budget]
}

@MainActor
final class SwiftDataBudgetRepository: BudgetRepository {
    private let context: ModelContext
    private let onSave: (() -> Void)?

    init(context: ModelContext, onSave: (() -> Void)? = nil) {
        self.context = context
        self.onSave = onSave
    }

    private func save() throws {
        try context.save()
        onSave?()
    }

    func add(_ b: Budget) throws {
        context.insert(b)
        try save()
    }

    func update(_ b: Budget) throws { try save() }

    func delete(id: UUID) throws {
        guard let b = try find(id: id) else { throw RepositoryError.notFound("Budget \(id)") }
        context.delete(b)
        try save()
    }

    func find(id: UUID) throws -> Budget? {
        var d = FetchDescriptor<Budget>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func findByCategory(_ categoryId: UUID, period: BudgetPeriod) throws -> Budget? {
        let periodRaw = period.rawValue
        let d = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.periodRaw == periodRaw }
        )
        let results = try context.fetch(d)
        return results.first { $0.category?.id == categoryId }
    }

    func all() throws -> [Budget] {
        let d = FetchDescriptor<Budget>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return try context.fetch(d)
    }
}
