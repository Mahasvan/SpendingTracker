import Foundation
import SwiftData

struct TransactionQuery {
    var dateFrom: Date?
    var dateTo: Date?
    var type: TxType?
    var categoryIds: [UUID]?
    var paymentMethodIds: [UUID]?
    var minAmount: Decimal?
    var maxAmount: Decimal?
    var textQuery: String?
    var limit: Int?
    var sortBy: SortBy = .dateDescending

    enum SortBy {
        case dateAscending
        case dateDescending
        case amountAscending
        case amountDescending
    }

    static let all = TransactionQuery()
}

@MainActor
protocol TransactionRepository: AnyObject {
    func add(_ tx: Transaction) throws
    func update(_ tx: Transaction) throws
    func delete(id: UUID) throws
    func find(id: UUID) throws -> Transaction?
    func fetch(_ query: TransactionQuery) throws -> [Transaction]
    func count(_ query: TransactionQuery) throws -> Int
}

@MainActor
final class SwiftDataTransactionRepository: TransactionRepository {
    private let context: ModelContext

    /// Invoked after every successful save so the vault can be re-snapshotted.
    var onSave: (() -> Void)?

    init(context: ModelContext) {
        self.context = context
    }

    private func save() throws {
        try context.save()
        onSave?()
    }

    func add(_ tx: Transaction) throws {
        context.insert(tx)
        try save()
    }

    func update(_ tx: Transaction) throws {
        tx.updatedAt = .now
        try save()
    }

    func delete(id: UUID) throws {
        guard let tx = try find(id: id) else {
            throw RepositoryError.notFound("Transaction \(id)")
        }
        context.delete(tx)
        try save()
    }

    func find(id: UUID) throws -> Transaction? {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetch(_ query: TransactionQuery) throws -> [Transaction] {
        let descriptor = makeDescriptor(query)
        let results = try context.fetch(descriptor)
        return applyInMemoryFilters(results, query: query)
    }

    func count(_ query: TransactionQuery) throws -> Int {
        try fetch(query).count
    }

    private func makeDescriptor(_ q: TransactionQuery) -> FetchDescriptor<Transaction> {
        let dateFrom = q.dateFrom
        let dateTo = q.dateTo
        let typeRaw = q.type?.rawValue

        let predicate = #Predicate<Transaction> { tx in
            (dateFrom == nil || tx.date >= dateFrom!) &&
            (dateTo == nil || tx.date <= dateTo!) &&
            (typeRaw == nil || tx.typeRaw == typeRaw!)
        }

        let sort: [SortDescriptor<Transaction>]
        switch q.sortBy {
        case .dateAscending:
            sort = [SortDescriptor(\.date, order: .forward)]
        case .dateDescending:
            sort = [SortDescriptor(\.date, order: .reverse)]
        case .amountAscending:
            sort = [SortDescriptor(\.amount, order: .forward)]
        case .amountDescending:
            sort = [SortDescriptor(\.amount, order: .reverse)]
        }

        var descriptor = FetchDescriptor<Transaction>(predicate: predicate, sortBy: sort)
        if let limit = q.limit {
            descriptor.fetchLimit = limit
        }
        return descriptor
    }

    private func applyInMemoryFilters(_ txs: [Transaction], query: TransactionQuery) -> [Transaction] {
        var results = txs
        if let ids = query.categoryIds, !ids.isEmpty {
            results = results.filter { tx in
                guard let cid = tx.category?.id else { return false }
                return ids.contains(cid)
            }
        }
        if let ids = query.paymentMethodIds, !ids.isEmpty {
            results = results.filter { tx in
                guard let pid = tx.paymentMethod?.id else { return false }
                return ids.contains(pid)
            }
        }
        if let minA = query.minAmount {
            results = results.filter { $0.amount >= minA }
        }
        if let maxA = query.maxAmount {
            results = results.filter { $0.amount <= maxA }
        }
        if let q = query.textQuery, !q.isEmpty {
            let needle = q.lowercased()
            results = results.filter { tx in
                tx.note.lowercased().contains(needle) ||
                (tx.category?.name.lowercased().contains(needle) ?? false) ||
                (tx.paymentMethod?.name.lowercased().contains(needle) ?? false)
            }
        }
        if let limit = query.limit, results.count > limit {
            results = Array(results.prefix(limit))
        }
        return results
    }
}
