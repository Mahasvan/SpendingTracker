import Foundation
import SwiftData

@MainActor
protocol PaymentMethodRepository: AnyObject {
    func add(_ pm: PaymentMethod) throws
    func update(_ pm: PaymentMethod) throws
    func delete(id: UUID) throws
    func find(id: UUID) throws -> PaymentMethod?
    func findByName(_ name: String) throws -> PaymentMethod?
    func all(includeArchived: Bool) throws -> [PaymentMethod]
}

@MainActor
final class SwiftDataPaymentMethodRepository: PaymentMethodRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func add(_ pm: PaymentMethod) throws {
        context.insert(pm)
        try context.save()
    }

    func update(_ pm: PaymentMethod) throws { try context.save() }

    func delete(id: UUID) throws {
        guard let pm = try find(id: id) else { throw RepositoryError.notFound("PaymentMethod \(id)") }
        context.delete(pm)
        try context.save()
    }

    func find(id: UUID) throws -> PaymentMethod? {
        var d = FetchDescriptor<PaymentMethod>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func findByName(_ name: String) throws -> PaymentMethod? {
        let target = name
        var d = FetchDescriptor<PaymentMethod>(predicate: #Predicate { $0.name == target })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func all(includeArchived: Bool = false) throws -> [PaymentMethod] {
        let d = FetchDescriptor<PaymentMethod>(sortBy: [SortDescriptor(\.name, order: .forward)])
        let results = try context.fetch(d)
        return includeArchived ? results : results.filter { !$0.archived }
    }
}
