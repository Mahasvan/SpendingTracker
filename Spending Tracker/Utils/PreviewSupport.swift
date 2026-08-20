import Foundation
import SwiftData

#if DEBUG
/// Helpers for constructing in-memory model containers and sample data for
/// SwiftUI #Preview macros. DEBUG-only so this code never ships in release.
enum PreviewSupport {
    /// A UserDefaults suite isolated from the app's real defaults, so previews
    /// never read persisted user settings. The suite persists across preview
    /// sessions, so `makeSettings()` / `makeContainer()` force the biometric
    /// lock off every time — a previous preview toggle must not leak forward.
    private static let previewDefaults: UserDefaults =
        UserDefaults(suiteName: "SpendingTrackerPreview")!

    /// AppSettings wired to the isolated preview defaults — biometric lock
    /// forced off so ContentView/LockView never prompt for Touch ID.
    static func makeSettings() -> AppSettings {
        let settings = AppSettings(defaults: previewDefaults)
        settings.requireBiometricUnlock = false
        return settings
    }

    /// Creates an in-memory ModelContainer with the app's schema, seeded with
    /// default categories and payment methods.
    @MainActor
    static func makeSeededContainer() -> ModelContainer {
        let schema = Schema([
            Transaction.self, Category.self, PaymentMethod.self,
            Budget.self, ChatSession.self, ChatMessage.self
        ])
        let config = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        )
        let container = try! ModelContainer(for: schema, configurations: [config])
        DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
        return container
    }

    /// Builds a full AppContainer from an in-memory seeded container, using
    /// preview-isolated AppSettings with biometric lock forced off.
    @MainActor
    static func makeContainer() -> AppContainer {
        let container = AppContainer(modelContainer: makeSeededContainer(), defaults: previewDefaults)
        container.settings.requireBiometricUnlock = false
        return container
    }

    /// Inserts sample transactions into the container's context and returns them.
    @MainActor
    static func seedSampleTransactions(in container: ModelContainer) -> [Transaction] {
        let ctx = container.mainContext
        let cats = (try? ctx.fetch(FetchDescriptor<Category>())) ?? []
        let pms = (try? ctx.fetch(FetchDescriptor<PaymentMethod>())) ?? []
        func cat(_ name: String) -> Category? { cats.first { $0.name == name } }
        func pm(_ name: String) -> PaymentMethod? { pms.first { $0.name == name } }

        let txs = [
            Transaction(amount: 450, type: .expense, date: .now, note: "Lunch at cafe",
                        category: cat("Food"), paymentMethod: pm("UPI")),
            Transaction(amount: 3200, type: .expense, date: .now.addingTimeInterval(-86400),
                        note: "Weekly groceries", category: cat("Groceries"), paymentMethod: pm("Credit Card")),
            Transaction(amount: 120, type: .expense, date: .now.addingTimeInterval(-172800),
                        note: "Metro card top-up", category: cat("Transport"), paymentMethod: pm("Cash")),
            Transaction(amount: 50000, type: .income, date: .now.addingTimeInterval(-259200),
                        note: "Monthly salary", category: cat("Salary"), paymentMethod: pm("Bank Transfer")),
            Transaction(amount: 800, type: .expense, date: .now.addingTimeInterval(-432000),
                        note: "Movie night", category: cat("Entertainment"), paymentMethod: pm("UPI")),
            Transaction(amount: 250, type: .expense, date: .now.addingTimeInterval(-604800),
                        note: "", category: nil, paymentMethod: pm("Cash")),
        ]
        for tx in txs { ctx.insert(tx) }
        try? ctx.save()
        return txs
    }

    // MARK: - Standalone sample objects (no ModelContext needed)

    static func sampleCategory(name: String = "Food", color: String = "#E57373",
                               icon: String = "fork.knife") -> Category {
        Category(name: name, colorHex: color, systemImage: icon)
    }

    static func samplePaymentMethod(name: String = "UPI", kind: PMKind = .upi) -> PaymentMethod {
        PaymentMethod(name: name, kind: kind)
    }

    static func sampleTransaction(note: String = "Lunch at cafe", amount: Decimal = 450,
                                  type: TxType = .expense, category: Category? = nil,
                                  paymentMethod: PaymentMethod? = nil) -> Transaction {
        Transaction(amount: amount, type: type, note: note,
                    category: category, paymentMethod: paymentMethod)
    }
}
#endif
