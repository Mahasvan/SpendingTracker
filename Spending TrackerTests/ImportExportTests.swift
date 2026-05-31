import Testing
import Foundation
import SwiftData
@testable import Spending_Tracker

@MainActor
struct ImportExportTests {
    @Test
    func roundTripPreservesData() throws {
        let container = try TestSupport.makeContainer()
        TestSupport.seedDefaults(in: container)
        let ctx = container.mainContext
        let catRepo = SwiftDataCategoryRepository(context: ctx)
        let txRepo = SwiftDataTransactionRepository(context: ctx)

        let food = try catRepo.findByName("Food")!
        try txRepo.add(Transaction(amount: 100, type: .expense, note: "lunch", category: food))
        try txRepo.add(Transaction(amount: 250, type: .expense, note: "dinner", category: food))

        let svc = ImportExportService(context: ctx)
        let data = try svc.exportAll(includeChatHistory: false)

        // Build a fresh store and import the data
        let fresh = try TestSupport.makeContainer()
        let svc2 = ImportExportService(context: fresh.mainContext)
        let summary = try svc2.importBackup(data, mode: .merge)
        #expect(summary.transactionsUpserted == 2)

        let importedTxs = try fresh.mainContext.fetch(FetchDescriptor<Transaction>())
        #expect(importedTxs.count == 2)
        #expect(importedTxs.compactMap(\.category).map(\.name).allSatisfy { $0 == "Food" })
    }

    @Test
    func mergeIsUnionByUUID() throws {
        let container = try TestSupport.makeContainer()
        TestSupport.seedDefaults(in: container)
        let ctx = container.mainContext

        // Existing: one tx
        try SwiftDataTransactionRepository(context: ctx).add(
            Transaction(amount: 50, type: .expense, note: "existing")
        )
        // Build a backup containing one different tx
        let other = Transaction(amount: 999, type: .income, note: "imported")
        let backup = BackupFile(
            version: BackupFile.currentVersion,
            exportedAt: .now,
            categories: [],
            paymentMethods: [],
            transactions: [
                BackupTransaction(
                    id: other.id, amount: 999, type: "income",
                    date: .now, note: "imported",
                    categoryId: nil, paymentMethodId: nil,
                    createdAt: .now, updatedAt: .now
                )
            ],
            budgets: [],
            chatSessions: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let summary = try ImportExportService(context: ctx).importBackup(data, mode: .merge)
        #expect(summary.transactionsUpserted == 1)
        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(all.count == 2)  // union, no duplicate
    }

    @Test
    func categoryDedupByNameRemapsReferences() throws {
        let container = try TestSupport.makeContainer()
        let ctx = container.mainContext
        let catRepo = SwiftDataCategoryRepository(context: ctx)
        // Existing local "Food" with one UUID
        let localFood = Category(name: "Food", colorHex: "#FF0000", systemImage: "fork.knife")
        try catRepo.add(localFood)

        // Backup contains a "Food" with a DIFFERENT UUID and a transaction referencing that UUID
        let importedFoodId = UUID()
        let txId = UUID()
        let backup = BackupFile(
            version: BackupFile.currentVersion,
            exportedAt: .now,
            categories: [
                BackupCategory(
                    id: importedFoodId, name: "Food", colorHex: "#00FF00",
                    systemImage: "leaf", archived: false, createdAt: .now
                )
            ],
            paymentMethods: [],
            transactions: [
                BackupTransaction(
                    id: txId, amount: 10, type: "expense",
                    date: .now, note: "via imported food",
                    categoryId: importedFoodId, paymentMethodId: nil,
                    createdAt: .now, updatedAt: .now
                )
            ],
            budgets: [],
            chatSessions: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        _ = try ImportExportService(context: ctx).importBackup(data, mode: .merge)
        let cats = try ctx.fetch(FetchDescriptor<Spending_Tracker.Category>())
        #expect(cats.filter { $0.name == "Food" }.count == 1)  // no duplicate
        let txs = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(txs.count == 1)
        #expect(txs.first?.category?.id == localFood.id)  // imported tx now points to local Food
    }

    @Test
    func replaceWipesLocalFirst() throws {
        let container = try TestSupport.makeContainer()
        TestSupport.seedDefaults(in: container)
        let ctx = container.mainContext
        try SwiftDataTransactionRepository(context: ctx).add(
            Transaction(amount: 1, type: .expense, note: "to be wiped")
        )

        let backup = BackupFile(
            version: BackupFile.currentVersion,
            exportedAt: .now,
            categories: [],
            paymentMethods: [],
            transactions: [],
            budgets: [],
            chatSessions: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let summary = try ImportExportService(context: ctx).importBackup(data, mode: .replace)
        #expect(summary.deletedBeforeReplace > 0)
        let txs = try ctx.fetch(FetchDescriptor<Transaction>())
        let cats = try ctx.fetch(FetchDescriptor<Spending_Tracker.Category>())
        #expect(txs.isEmpty)
        #expect(cats.isEmpty)
    }
}
