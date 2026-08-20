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

    /// Categorizes a single transaction using Apple Intelligence. No-op with an
    /// informative error on devices without Apple Intelligence / macOS 26.
    func categorize(_ tx: Transaction) async {
        guard #available(macOS 26.0, iOS 26.0, *) else {
            errorMessage = "Categorization requires Apple Intelligence (macOS 26+)."
            return
        }
        let status = AppleFoundationIntrospection.checkAvailability()
        guard status.isAvailable else {
            errorMessage = status.description
            return
        }
        do {
            let categories = try categoryRepo.all(includeArchived: false).map(\.name)
            guard !categories.isEmpty else {
                errorMessage = "No categories configured."
                return
            }
            let lastResort = categories.last { $0.lowercased() == "other" } ?? categories.last
            let categorizer = TransactionCategorizer()
            _ = try await categorizer.categorize([tx], categories: categories, lastResort: lastResort) { uuid, name in
                guard let resolved = try categoryRepo.findByName(name) else { return }
                guard let target = try repo.find(id: uuid) else { return }
                target.category = resolved
                try repo.update(target)
            }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Categorizes all currently-loaded uncategorized transactions in one pass.
    func categorizeAllUncategorized() async {
        guard #available(macOS 26.0, iOS 26.0, *) else {
            errorMessage = "Categorization requires Apple Intelligence (macOS 26+)."
            return
        }
        let status = AppleFoundationIntrospection.checkAvailability()
        guard status.isAvailable else {
            errorMessage = status.description
            return
        }
        let targets = transactions.filter { $0.category == nil }
        guard !targets.isEmpty else { return }
        do {
            let categories = try categoryRepo.all(includeArchived: false).map(\.name)
            guard !categories.isEmpty else {
                errorMessage = "No categories configured."
                return
            }
            let lastResort = categories.last { $0.lowercased() == "other" } ?? categories.last
            let categorizer = TransactionCategorizer()
            _ = try await categorizer.categorize(targets, categories: categories, lastResort: lastResort) { uuid, name in
                guard let resolved = try categoryRepo.findByName(name) else { return }
                guard let target = try repo.find(id: uuid) else { return }
                target.category = resolved
                try repo.update(target)
            }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
