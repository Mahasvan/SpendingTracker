import CryptoKit
import Foundation
import LocalAuthentication
import SwiftData
import XCTest
@testable import Spending_Tracker

/// Mock VaultKeyStore for testing
final class MockVaultKeyStore: VaultKeyStore {
    private var key: SymmetricKey?
    var shouldThrowOnLoad = false

    func loadKey(context: LAContext) throws -> SymmetricKey {
        if shouldThrowOnLoad {
            throw KeychainError(status: errSecItemNotFound)
        }
        guard let key = key else {
            throw KeychainError(status: errSecItemNotFound)
        }
        return key
    }

    func createKey() throws {
        key = SymmetricKey(size: .bits256)
    }

    func deleteKey() throws {
        key = nil
    }

    var hasKey: Bool {
        key != nil
    }
}

final class VaultMigrationTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var vaultURL: URL!
    private var plaintextContainer: ModelContainer!
    private var inMemoryContainer: ModelContainer!
    private var inMemoryContext: ModelContext!
    private var importExportService: ImportExportService!
    private var mockKeyStore: MockVaultKeyStore!
    private var vaultCoordinator: VaultCoordinator!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directory
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        vaultURL = temporaryDirectory.appendingPathComponent("vault.enc")

        // Create plaintext container (on-disk)
        let plaintextConfig = ModelConfiguration(
            "PlaintextStore",
            schema: PersistenceController.schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        plaintextContainer = try ModelContainer(
            for: Transaction.self,
            configurations: [plaintextConfig]
        )

        // Seed plaintext store with test data
        let plaintextContext = plaintextContainer.mainContext
        let category = Category(name: "Food", colorHex: "#FF0000", systemImage: "fork.knife")
        plaintextContext.insert(category)

        let paymentMethod = PaymentMethod(name: "Credit Card", kind: .creditCard)
        plaintextContext.insert(paymentMethod)

        let transaction = Transaction(
            amount: 25.75,
            type: .expense,
            date: Date(),
            note: "Grocery shopping",
            category: category,
            paymentMethod: paymentMethod
        )
        plaintextContext.insert(transaction)
        try plaintextContext.save()

        // Create in-memory container for vault
        inMemoryContainer = try ModelContainer(
            for: Transaction.self,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        inMemoryContext = ModelContext(inMemoryContainer)

        importExportService = ImportExportService(context: inMemoryContext)
        mockKeyStore = MockVaultKeyStore()
        try mockKeyStore.createKey()

        vaultCoordinator = VaultCoordinator(
            keyStore: mockKeyStore,
            context: inMemoryContext,
            vaultURL: vaultURL,
            importExportService: importExportService,
            migrationContainer: plaintextContainer
        )
    }

    override func tearDown() async throws {
        try await super.tearDown()

        // Clean up temporary directory
        try? FileManager.default.removeItem(at: temporaryDirectory)

        // Reset migration flag
        UserDefaults.standard.removeObject(forKey: "vaultMigrationCompleted")
    }

    func testMigrationFromPlaintextToVault() throws {
        // Verify vault doesn't exist yet
        XCTAssertFalse(FileManager.default.fileExists(atPath: vaultURL.path))
        XCTAssertFalse(vaultCoordinator.isMigrationCompleted)

        // Load vault (should trigger migration)
        try vaultCoordinator.loadVault(authContext: LAContext())

        // Verify vault was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))
        XCTAssertTrue(vaultCoordinator.isMigrationCompleted)

        // Verify data was migrated to in-memory context
        let transactions = try inMemoryContext.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.amount, 25.75)
        XCTAssertEqual(transactions.first?.note, "Grocery shopping")

        let categories = try inMemoryContext.fetch(FetchDescriptor<Category>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.name, "Food")

        let paymentMethods = try inMemoryContext.fetch(FetchDescriptor<PaymentMethod>())
        XCTAssertEqual(paymentMethods.count, 1)
        XCTAssertEqual(paymentMethods.first?.name, "Credit Card")
    }

    func testMigrationWithEmptyPlaintextStore() throws {
        // Delete the plaintext data
        let plaintextContext = plaintextContainer.mainContext
        for tx in try plaintextContext.fetch(FetchDescriptor<Transaction>()) {
            plaintextContext.delete(tx)
        }
        for cat in try plaintextContext.fetch(FetchDescriptor<Category>()) {
            plaintextContext.delete(cat)
        }
        for pm in try plaintextContext.fetch(FetchDescriptor<PaymentMethod>()) {
            plaintextContext.delete(pm)
        }
        try plaintextContext.save()

        // Load vault (should complete migration without creating vault)
        try vaultCoordinator.loadVault(authContext: LAContext())

        // Migration should be marked complete even with no data
        XCTAssertTrue(vaultCoordinator.isMigrationCompleted)

        // Vault should not exist if there was no data (below threshold)
        XCTAssertFalse(FileManager.default.fileExists(atPath: vaultURL.path))
    }

    func testMigrationOnlyRunsOnce() throws {
        // First migration
        try vaultCoordinator.loadVault(authContext: LAContext())
        XCTAssertTrue(vaultCoordinator.isMigrationCompleted)
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))

        // Clear in-memory context
        for tx in try inMemoryContext.fetch(FetchDescriptor<Transaction>()) {
            inMemoryContext.delete(tx)
        }
        for cat in try inMemoryContext.fetch(FetchDescriptor<Category>()) {
            inMemoryContext.delete(cat)
        }
        for pm in try inMemoryContext.fetch(FetchDescriptor<PaymentMethod>()) {
            inMemoryContext.delete(pm)
        }
        try inMemoryContext.save()

        // Load vault again (should not re-migrate, just load from vault)
        try vaultCoordinator.loadVault(authContext: LAContext())

        // Data should still be there (loaded from vault, not re-migrated)
        let transactions = try inMemoryContext.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
    }

    func testMigratedVaultIsEncrypted() throws {
        // Run migration
        try vaultCoordinator.loadVault(authContext: LAContext())

        // Verify vault file is encrypted (not plaintext)
        let vaultData = try Data(contentsOf: vaultURL)
        let vaultString = String(data: vaultData, encoding: .utf8) ?? ""

        // Should not contain plaintext data
        XCTAssertFalse(vaultString.contains("Food"))
        XCTAssertFalse(vaultString.contains("Credit Card"))
        XCTAssertFalse(vaultString.contains("Grocery shopping"))
    }
}
