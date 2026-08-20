import Foundation
import SwiftData

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let settings: AppSettings
    let capabilityStore: ModelCapabilityStore

    let transactionRepo: any TransactionRepository
    let categoryRepo: any CategoryRepository
    let paymentMethodRepo: any PaymentMethodRepository
    let budgetRepo: any BudgetRepository
    let chatRepo: any ChatRepository

    let toolRegistry: ToolRegistry
    let toolContext: ToolContext
    let importExportService: ImportExportService

    let transactionsVM: TransactionsViewModel
    let searchVM: SearchViewModel
    let budgetsVM: BudgetsViewModel
    let dashboardVM: DashboardViewModel
    let chatService: ChatService

    init(modelContainer: ModelContainer, defaults: UserDefaults = .standard) {
        self.modelContainer = modelContainer
        let context = modelContainer.mainContext
        self.settings = AppSettings(defaults: defaults)
        self.capabilityStore = ModelCapabilityStore(settings: settings)

        let txRepo = SwiftDataTransactionRepository(context: context)
        let catRepo = SwiftDataCategoryRepository(context: context)
        let pmRepo = SwiftDataPaymentMethodRepository(context: context)
        let bRepo = SwiftDataBudgetRepository(context: context)
        let cRepo = SwiftDataChatRepository(context: context)

        self.transactionRepo = txRepo
        self.categoryRepo = catRepo
        self.paymentMethodRepo = pmRepo
        self.budgetRepo = bRepo
        self.chatRepo = cRepo

        self.importExportService = ImportExportService(context: context)

        self.toolContext = ToolContext(
            transactionRepo: txRepo,
            categoryRepo: catRepo,
            paymentMethodRepo: pmRepo,
            budgetRepo: bRepo
        )
        self.toolRegistry = ToolRegistry.defaultRegistry()

        self.transactionsVM = TransactionsViewModel(
            repo: txRepo,
            categoryRepo: catRepo,
            pmRepo: pmRepo
        )
        self.searchVM = SearchViewModel(
            repo: txRepo,
            categoryRepo: catRepo,
            pmRepo: pmRepo
        )
        self.budgetsVM = BudgetsViewModel(
            repo: bRepo,
            txRepo: txRepo,
            categoryRepo: catRepo
        )
        self.dashboardVM = DashboardViewModel(
            txRepo: txRepo,
            budgetsVM: self.budgetsVM
        )
        self.chatService = ChatService(
            registry: toolRegistry,
            toolContext: toolContext,
            settings: settings,
            capabilityStore: capabilityStore
        )
    }
}
