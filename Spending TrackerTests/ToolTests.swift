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

    @Test @MainActor
    func getCategoriesReturnsOnlyName() async throws {
        let ctx = try makeContext()
        let result = try await GetCategoriesTool().run(arguments: .object([:]), context: ctx)
        let items = try #require(result.arrayValue)
        #expect(!items.isEmpty)
        for item in items {
            let obj = try #require(item.objectValue)
            #expect(Array(obj.keys) == ["name"])
        }
    }

    @Test @MainActor
    func getPaymentMethodsReturnsOnlyName() async throws {
        let ctx = try makeContext()
        let result = try await GetPaymentMethodsTool().run(arguments: .object([:]), context: ctx)
        let items = try #require(result.arrayValue)
        #expect(!items.isEmpty)
        for item in items {
            let obj = try #require(item.objectValue)
            #expect(Array(obj.keys) == ["name"])
        }
    }

    @Test @MainActor
    func addTransactionResultOmitsIdFields() async throws {
        let ctx = try makeContext()
        let args: JSONValue = .object([
            "amount": .number(100),
            "type": .string("expense"),
            "category": .string("Food"),
            "payment_method": .string("Cash")
        ])
        let result = try await AddTransactionTool().run(arguments: args, context: ctx)
        let obj = try #require(result.objectValue)
        #expect(obj["category"]?.stringValue == "Food")
        #expect(obj["payment_method"]?.stringValue == "Cash")
        #expect(obj["category_id"] == nil)
        #expect(obj["payment_method_id"] == nil)
    }
}
