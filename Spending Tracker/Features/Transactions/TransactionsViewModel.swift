import Foundation
import Observation

@MainActor
@Observable
final class TransactionsViewModel {
    private let repo: any TransactionRepository
    private let categoryRepo: any CategoryRepository
    private let pmRepo: any PaymentMethodRepository

    var transactions: [Transaction] = []
    var categories: [Category] = []
    var paymentMethods: [PaymentMethod] = []
    var query: TransactionQuery = .all
    var errorMessage: String?

    init(
        repo: any TransactionRepository,
        categoryRepo: any CategoryRepository,
        pmRepo: any PaymentMethodRepository
    ) {
        self.repo = repo
        self.categoryRepo = categoryRepo
        self.pmRepo = pmRepo
    }

    func load() {
        do {
            transactions = try repo.fetch(query)
            categories = try categoryRepo.all(includeArchived: false)
            paymentMethods = try pmRepo.all(includeArchived: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ tx: Transaction) {
        do {
            try repo.delete(id: tx.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTransaction(_ tx: Transaction) {
        do {
            try repo.add(tx)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveEdited(_ tx: Transaction) {
        do {
            try repo.update(tx)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
