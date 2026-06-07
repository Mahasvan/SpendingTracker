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

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }
}
