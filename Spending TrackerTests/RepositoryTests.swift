import Testing
import Foundation
import SwiftData
@testable import Spending_Tracker

@MainActor
struct RepositoryTests {
    @Test
    func transactionAddFetchDelete() throws {
        let container = try TestSupport.makeContainer()
        TestSupport.seedDefaults(in: container)
        let ctx = container.mainContext
        let txRepo = SwiftDataTransactionRepository(context: ctx)
        let catRepo = SwiftDataCategoryRepository(context: ctx)

        let cat = try catRepo.findByName("Food")
        #expect(cat != nil)
        let tx = Transaction(amount: 100, type: .expense, note: "lunch", category: cat)
        try txRepo.add(tx)
        let all = try txRepo.fetch(.all)
        #expect(all.count == 1)
        try txRepo.delete(id: tx.id)
        #expect(try txRepo.fetch(.all).isEmpty)
    }

    @Test
    func queryFilterByType() throws {
        let container = try TestSupport.makeContainer()
        let ctx = container.mainContext
        let repo = SwiftDataTransactionRepository(context: ctx)
        try repo.add(Transaction(amount: 100, type: .expense))
        try repo.add(Transaction(amount: 200, type: .income))
        var q = TransactionQuery()
        q.type = .income
        let incomes = try repo.fetch(q)
        #expect(incomes.count == 1)
        #expect(incomes.first?.amount == 200)
    }

    @Test
    func budgetFindByCategory() throws {
        let container = try TestSupport.makeContainer()
        TestSupport.seedDefaults(in: container)
        let ctx = container.mainContext
        let catRepo = SwiftDataCategoryRepository(context: ctx)
        let bRepo = SwiftDataBudgetRepository(context: ctx)
        let food = try catRepo.findByName("Food")!
        try bRepo.add(Budget(amount: 5000, period: .monthly, category: food))
        let found = try bRepo.findByCategory(food.id, period: .monthly)
        #expect(found?.amount == 5000)
    }

    @Test
    func chatRepoSessionFlow() throws {
        let container = try TestSupport.makeContainer()
        let ctx = container.mainContext
        let repo = SwiftDataChatRepository(context: ctx)
        let session = try repo.createSession(title: "Test")
        try repo.append(ChatMessage(role: .user, content: "hi"), to: session)
        try repo.append(ChatMessage(role: .assistant, content: "hello"), to: session)
        let msgs = try repo.messages(in: session)
        #expect(msgs.count == 2)
        #expect(msgs.first?.content == "hi")
    }
}
