import Foundation
import SwiftData
@testable import Spending_Tracker

@MainActor
enum TestSupport {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Transaction.self,
            Category.self,
            PaymentMethod.self,
            Budget.self,
            ChatSession.self,
            ChatMessage.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func seedDefaults(in container: ModelContainer) {
        DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
    }
}
