import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    private let repo: any TransactionRepository
    private let categoryRepo: any CategoryRepository
    private let pmRepo: any PaymentMethodRepository

    var query: String = ""
    var dateFrom: Date?
    var dateTo: Date?
    var type: TxType?
    var selectedCategoryIds: Set<UUID> = []
    var selectedPMIds: Set<UUID> = []
    var minAmount: Decimal?
    var maxAmount: Decimal?

    var categories: [Category] = []
    var paymentMethods: [PaymentMethod] = []
    var results: [Transaction] = []
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

    func loadFilters() {
        do {
            categories = try categoryRepo.all(includeArchived: false)
            paymentMethods = try pmRepo.all(includeArchived: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search() {
        var q = TransactionQuery()
        q.textQuery = query.trimmingCharacters(in: .whitespaces).isEmpty ? nil : query
        q.dateFrom = dateFrom
        q.dateTo = dateTo
        q.type = type
        q.categoryIds = selectedCategoryIds.isEmpty ? nil : Array(selectedCategoryIds)
        q.paymentMethodIds = selectedPMIds.isEmpty ? nil : Array(selectedPMIds)
        q.minAmount = minAmount
        q.maxAmount = maxAmount
        q.sortBy = .dateDescending
        do {
            results = try repo.fetch(q)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        query = ""
        dateFrom = nil; dateTo = nil
        type = nil
        selectedCategoryIds = []
        selectedPMIds = []
        minAmount = nil; maxAmount = nil
        search()
    }
}
