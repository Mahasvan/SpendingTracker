import CryptoKit
import Foundation
import LocalAuthentication
import SwiftData
import XCTest
@testable import Spending_Tracker

@MainActor
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

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        vaultURL = temporaryDirectory.appendingPathComponent("vault.enc")

        modelContainer = try TestSupport.makeContainer()
        modelContext = modelContainer.mainContext

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
        try? FileManager.default.removeItem(at: temporaryDirectory)
        try await super.tearDown()
    }

    func testSnapshotLoadRoundTrip() throws {
        // Unlock (no vault yet -> seeds defaults and writes initial snapshot).
        try vaultCoordinator.loadVault(authContext: LAContext())

        // Add a distinctive transaction.
        let category = Category(name: "ZZTestCategory", colorHex: "#FF0000", systemImage: "fork.knife")
        modelContext.insert(category)
        let transaction = Transaction(
            amount: 10.50, type: .expense, date: Date(),
            note: "RoundTripLunch", category: category
        )
        modelContext.insert(transaction)
        try modelContext.save()

        // Snapshot, then wipe the in-memory store.
        try vaultCoordinator.snapshot()
        for tx in try modelContext.fetch(FetchDescriptor<Transaction>()) { modelContext.delete(tx) }
        for c in try modelContext.fetch(FetchDescriptor<Category>()) { modelContext.delete(c) }
        try modelContext.save()
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Transaction>()), 0)

        // Reload from the vault and confirm the transaction returns.
        try vaultCoordinator.loadVault(authContext: LAContext())
        let restored = try modelContext.fetch(FetchDescriptor<Transaction>())
        XCTAssertTrue(restored.contains { $0.note == "RoundTripLunch" })
    }

    func testLoadVaultSeedsDefaultsForNewUser() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: vaultURL.path))

        try vaultCoordinator.loadVault(authContext: LAContext())

        // Fresh install: defaults seeded into the in-memory store and a vault written.
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))
        XCTAssertGreaterThan(try modelContext.fetchCount(FetchDescriptor<Category>()), 0)
    }

    func testLoadVaultCreatesKeyWhenMissing() throws {
        try mockKeyStore.deleteKey()
        XCTAssertFalse(mockKeyStore.hasKey)

        try vaultCoordinator.loadVault(authContext: LAContext())
        XCTAssertTrue(mockKeyStore.hasKey)
        XCTAssertTrue(vaultCoordinator.isUnlocked)
    }

    func testSnapshotBeforeUnlockThrows() {
        // No loadVault call -> no cached key -> snapshot must refuse.
        XCTAssertThrowsError(try vaultCoordinator.snapshot()) { error in
            XCTAssertTrue(error is VaultCoordinatorError)
        }
    }

    func testSnapshotProducesEncryptedFile() throws {
        try vaultCoordinator.loadVault(authContext: LAContext())

        let category = Category(name: "SecretCategoryXYZ", colorHex: "#000000", systemImage: "circle")
        modelContext.insert(category)
        try modelContext.save()
        try vaultCoordinator.snapshot()

        let fileData = try Data(contentsOf: vaultURL)
        let fileString = String(data: fileData, encoding: .utf8) ?? ""
        XCTAssertFalse(fileString.contains("SecretCategoryXYZ"), "Vault file should be encrypted")
    }

    func testRepeatedSnapshotsSucceed() throws {
        // Regression: snapshot used to fail on the 2nd call (moveItem over existing file).
        try vaultCoordinator.loadVault(authContext: LAContext())
        try vaultCoordinator.snapshot()
        XCTAssertNoThrow(try vaultCoordinator.snapshot())
        XCTAssertNoThrow(try vaultCoordinator.snapshot())
    }

    func testDeleteVault() throws {
        try vaultCoordinator.loadVault(authContext: LAContext())
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))

        try vaultCoordinator.deleteVault()
        XCTAssertFalse(FileManager.default.fileExists(atPath: vaultURL.path))
        XCTAssertFalse(vaultCoordinator.isMigrationCompleted)
    }

    func testScheduleSnapshotWritesAfterDebounce() async throws {
        try vaultCoordinator.loadVault(authContext: LAContext())
        // Remove the file written during seeding to prove the scheduled write happens.
        try FileManager.default.removeItem(at: vaultURL)

        let category = Category(name: "Debounced", colorHex: "#000000", systemImage: "circle")
        modelContext.insert(category)
        try modelContext.save()

        vaultCoordinator.scheduleSnapshot()
        try await Task.sleep(nanoseconds: 2_500_000_000)

        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))
    }
}
