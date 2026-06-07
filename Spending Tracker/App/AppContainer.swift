import Foundation
import LocalAuthentication
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

    let vaultCoordinator: VaultCoordinator
    private let migrationContainer: ModelContainer?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = modelContainer.mainContext
        self.settings = AppSettings()
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

        // Only create a migration container when a legacy plaintext store
        // actually exists; never create/seed a plaintext store for new users.
        self.migrationContainer = PersistenceController.makeLegacyMigrationContainer()

        // Setup vault coordinator
        let vaultURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("vault.enc", isDirectory: false)
        let keyStore = KeychainVaultKeyStore()
        self.vaultCoordinator = VaultCoordinator(
            keyStore: keyStore,
            context: context,
            vaultURL: vaultURL,
            importExportService: importExportService,
            migrationContainer: migrationContainer
        )

        // Wire repository saves to schedule encrypted snapshots. Safe to
        // reference self here since all stored properties are initialized.
        let snapshotHook: () -> Void = { [weak self] in self?.scheduleSnapshot() }
        txRepo.onSave = snapshotHook
        catRepo.onSave = snapshotHook
        pmRepo.onSave = snapshotHook
        bRepo.onSave = snapshotHook
        cRepo.onSave = snapshotHook
    }

    /// Loads the vault after successful authentication.
    /// - Parameter authContext: The LAContext from biometric authentication.
    /// - Throws: Errors from vault loading.
    func loadVault(authContext: LAContext) throws {
        try vaultCoordinator.loadVault(authContext: authContext)
    }

    /// Schedules a snapshot to be taken after a short delay.
    func scheduleSnapshot() {
        vaultCoordinator.scheduleSnapshot()
    }

    /// Immediately takes a snapshot.
    func snapshot() throws {
        try vaultCoordinator.snapshot()
    }
}
