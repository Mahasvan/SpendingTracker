import Testing
import Foundation
import SwiftData
@testable import Spending_Tracker

@MainActor
@Suite(.serialized)
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
    func addTransactionViaTool() async throws {
        let ctx = try makeContext()
        let tool = AddTransactionTool()
        let args: JSONValue = .object([
            "amount": .number(150.0),
            "type": .string("expense"),
            "category": .string("Food"),
            "payment_method": .string("Cash"),
            "note": .string("test")
        ])
        let result = try await tool.run(arguments: args, context: ctx)
        #expect(result["amount"]?.numberValue == 150.0)
        let all = try ctx.transactionRepo.fetch(.all)
        #expect(all.count == 1)
        #expect(all.first?.note == "test")
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
    func listTransactionsFilters() async throws {
        let ctx = try makeContext()
        _ = try await AddTransactionTool().run(arguments: .object([
            "amount": .number(100), "type": .string("expense"), "category": .string("Food")
        ]), context: ctx)
        _ = try await AddTransactionTool().run(arguments: .object([
            "amount": .number(500), "type": .string("income"), "category": .string("Salary")
        ]), context: ctx)

        let result = try await ListTransactionsTool().run(
            arguments: .object(["type": .string("income")]),
            context: ctx
        )
        #expect(result["count"]?.numberValue == 1)
    }

    @Test @MainActor
    func summaryTotals() async throws {
        let ctx = try makeContext()
        _ = try await AddTransactionTool().run(arguments: .object([
            "amount": .number(100), "type": .string("expense")
        ]), context: ctx)
        _ = try await AddTransactionTool().run(arguments: .object([
            "amount": .number(500), "type": .string("income")
        ]), context: ctx)
        let summary = try await GetSummaryTool().run(
            arguments: .object(["period": .string("this_month")]),
            context: ctx
        )
        #expect(summary["total_expense"]?.numberValue == 100)
        #expect(summary["total_income"]?.numberValue == 500)
        #expect(summary["net"]?.numberValue == 400)
    }

    @Test @MainActor
    func createCategoryDuplicateFails() async throws {
        let ctx = try makeContext()
        await #expect(throws: ToolError.self) {
            _ = try await CreateCategoryTool().run(
                arguments: .object(["name": .string("Food")]),
                context: ctx
            )
        }
    }

    @Test @MainActor
    func deleteTransaction() async throws {
        let ctx = try makeContext()
        let added = try await AddTransactionTool().run(arguments: .object([
            "amount": .number(50), "type": .string("expense")
        ]), context: ctx)
        let id = added["id"]?.stringValue ?? ""
        let res = try await DeleteTransactionTool().run(
            arguments: .object(["id": .string(id)]),
            context: ctx
        )
        #expect(res["deleted"]?.boolValue == true)
        let all = try ctx.transactionRepo.fetch(.all)
        #expect(all.isEmpty)
    }
}
