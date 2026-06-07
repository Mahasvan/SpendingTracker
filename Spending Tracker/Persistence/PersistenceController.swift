import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([
        Transaction.self,
        Category.self,
        PaymentMethod.self,
        Budget.self,
        ChatSession.self,
        ChatMessage.self
    ])

    /// Creates an in-memory container for the encrypted vault.
    /// - Returns: An in-memory ModelContainer.
    static func makeInMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            // Don't seed data - it will come from the vault
            return container
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }

    /// Creates an on-disk container for migration from plaintext.
    /// - Returns: An on-disk ModelContainer.
    static func makeOnDiskContainer() -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            return makeInMemoryContainer()
        } else {
            return makeOnDiskContainer()
        }
    }
}
