import Foundation
import SwiftData

@MainActor
protocol CategoryRepository: AnyObject {
    func add(_ c: Category) throws
    func update(_ c: Category) throws
    func delete(id: UUID) throws
    func find(id: UUID) throws -> Category?
    func findByName(_ name: String) throws -> Category?
    func all(includeArchived: Bool) throws -> [Category]
}

@MainActor
final class SwiftDataCategoryRepository: CategoryRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func add(_ c: Category) throws {
        context.insert(c)
        try context.save()
    }

    func update(_ c: Category) throws { try context.save() }

    func delete(id: UUID) throws {
        guard let c = try find(id: id) else { throw RepositoryError.notFound("Category \(id)") }
        context.delete(c)
        try context.save()
    }

    func find(id: UUID) throws -> Category? {
        var d = FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func findByName(_ name: String) throws -> Category? {
        let target = name
        var d = FetchDescriptor<Category>(predicate: #Predicate { $0.name == target })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func all(includeArchived: Bool = false) throws -> [Category] {
        let d = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name, order: .forward)])
        let results = try context.fetch(d)
        return includeArchived ? results : results.filter { !$0.archived }
    }
}
