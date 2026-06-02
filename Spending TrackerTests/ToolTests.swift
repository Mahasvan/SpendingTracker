import Testing
import Foundation
import SwiftData
@testable import Spending_Tracker

@MainActor
struct ToolTests {
    private func makeContext() throws -> ToolContext {
        let container = try TestSupport.makeContainer()
        TestSupport.seedDefaults(in: container)
        let ctx = container.mainContext
        return ToolContext(
            transactionRepo: SwiftDataTransactionRepository(context: ctx),
            categoryRepo: SwiftDataCategoryRepository(context: ctx),
            paymentMethodRepo: SwiftDataPaymentMethodRepository(context: ctx),
            budgetRepo: SwiftDataBudgetRepository(context: ctx)
        )
    }

    @Test @MainActor
    func addTransactionRejectsNegative() async throws {
        let ctx = try makeContext()
        let tool = AddTransactionTool()
        let args: JSONValue = .object([
            "amount": .number(-5),
            "type": .string("expense")
        ])
        await #expect(throws: ToolError.self) {
            _ = try await tool.run(arguments: args, context: ctx)
        }
    }
}
