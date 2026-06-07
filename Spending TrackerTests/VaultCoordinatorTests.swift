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
    var loadContext: LAContext?

    func loadKey(context: LAContext) throws -> SymmetricKey {
        loadContext = context
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

final class VaultCoordinatorTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var vaultURL: URL!
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
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

        // Create in-memory container
        modelContainer = try ModelContainer(
            for: Transaction.self,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        modelContext = ModelContext(modelContainer)

        importExportService = ImportExportService(context: modelContext)
        mockKeyStore = MockVaultKeyStore()
        try mockKeyStore.createKey()

        vaultCoordinator = VaultCoordinator(
            keyStore: mockKeyStore,
            context: modelContext,
            vaultURL: vaultURL,
            importExportService: importExportService,
            migrationContainer: nil
        )
    }

    override func tearDown() async throws {
        try await super.tearDown()

        // Clean up temporary directory
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testSnapshotLoadRoundTrip() throws {
        // Add some test data
        let category = Category(name: "Food", colorHex: "#FF0000", systemImage: "fork.knife")
        modelContext.insert(category)

        let paymentMethod = PaymentMethod(name: "Credit Card", kind: .creditCard)
        modelContext.insert(paymentMethod)

        let transaction = Transaction(
            amount: 10.50,
            type: .expense,
            date: Date(),
            note: "Lunch",
            category: category,
            paymentMethod: paymentMethod
        )
        modelContext.insert(transaction)
        try modelContext.save()

        // Snapshot
        try vaultCoordinator.snapshot()
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))

        // Clear the context
        for tx in try modelContext.fetch(FetchDescriptor<Transaction>()) {
            modelContext.delete(tx)
        }
        for cat in try modelContext.fetch(FetchDescriptor<Category>()) {
            modelContext.delete(cat)
        }
        for pm in try modelContext.fetch(FetchDescriptor<PaymentMethod>()) {
            modelContext.delete(pm)
        }
        try modelContext.save()

        // Load vault
        try vaultCoordinator.loadVault(authContext: LAContext())

        // Verify data was restored
        let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.amount, 10.50)
        XCTAssertEqual(transactions.first?.note, "Lunch")

        let categories = try modelContext.fetch(FetchDescriptor<Category>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.name, "Food")

        let paymentMethods = try modelContext.fetch(FetchDescriptor<PaymentMethod>())
        XCTAssertEqual(paymentMethods.count, 1)
        XCTAssertEqual(paymentMethods.first?.name, "Credit Card")
    }

    func testLoadVaultWithNoVaultFile() throws {
        // Should create key and not fail when vault doesn't exist
        XCTAssertFalse(FileManager.default.fileExists(atPath: vaultURL.path))
        try vaultCoordinator.loadVault(authContext: LAContext())
        // Should succeed (no data to load)
    }

    func testLoadVaultWithNoKey() throws {
        // Delete the key
        try mockKeyStore.deleteKey()
        XCTAssertFalse(mockKeyStore.hasKey)

        // Load should create a new key
        try vaultCoordinator.loadVault(authContext: LAContext())
        XCTAssertTrue(mockKeyStore.hasKey)
    }

    func testSnapshotCreatesEncryptedFile() throws {
        // Add test data
        let category = Category(name: "Test", colorHex: "#000000", systemImage: "circle")
        modelContext.insert(category)
        try modelContext.save()

        // Snapshot
        try vaultCoordinator.snapshot()

        // Verify file exists and is not plaintext
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))
        let fileData = try Data(contentsOf: vaultURL)

        // The file should not contain the plaintext "Test"
        let fileString = String(data: fileData, encoding: .utf8) ?? ""
        XCTAssertFalse(fileString.contains("Test"), "Vault file should be encrypted, not plaintext")
    }

    func testDeleteVault() throws {
        // Create a vault
        let category = Category(name: "Test", colorHex: "#000000", systemImage: "circle")
        modelContext.insert(category)
        try modelContext.save()
        try vaultCoordinator.snapshot()

        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))

        // Delete vault
        try vaultCoordinator.deleteVault()

        XCTAssertFalse(FileManager.default.fileExists(atPath: vaultURL.path))
        XCTAssertFalse(vaultCoordinator.isMigrationCompleted)
    }

    func testScheduleSnapshot() async throws {
        // Add test data
        let category = Category(name: "Test", colorHex: "#000000", systemImage: "circle")
        modelContext.insert(category)
        try modelContext.save()

        // Schedule snapshot
        vaultCoordinator.scheduleSnapshot()

        // Wait for debounce (2 seconds)
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Verify snapshot was taken
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))
    }
}
