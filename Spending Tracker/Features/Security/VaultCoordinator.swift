import CryptoKit
import Foundation
import LocalAuthentication
import SwiftData

/// Coordinates vault encryption/decryption and data loading.
@MainActor
final class VaultCoordinator {
    private let keyStore: VaultKeyStore
    private let context: ModelContext
    private let vaultURL: URL
    private let importExportService: ImportExportService
    private let migrationContainer: ModelContainer?

    /// Debounce timer for snapshot requests.
    private var snapshotTask: Task<Void, Never>?

    /// UserDefaults key for migration flag.
    private static let migrationCompletedKey = "vaultMigrationCompleted"

    init(
        keyStore: VaultKeyStore,
        context: ModelContext,
        vaultURL: URL,
        importExportService: ImportExportService,
        migrationContainer: ModelContainer? = nil
    ) {
        self.keyStore = keyStore
        self.context = context
        self.vaultURL = vaultURL
        self.importExportService = importExportService
        self.migrationContainer = migrationContainer
    }

    // MARK: - Load

    /// Loads the vault into the in-memory context.
    /// - Parameter authContext: The LAContext from biometric authentication.
    /// - Throws: Errors from key loading, decryption, or import.
    func loadVault(authContext: LAContext) throws {
        // Ensure key exists
        if !keyStore.hasKey {
            try keyStore.createKey()
        }

        // Load key
        let key = try keyStore.loadKey(context: authContext)
        let vault = CryptoVault(key: key)

        // Check if vault file exists
        if !FileManager.default.fileExists(atPath: vaultURL.path) {
            // First run: no vault yet, try migration from plaintext store
            try migrateFromPlaintext(vault: vault)
            return
        }

        // Decrypt vault
        let encryptedData = try Data(contentsOf: vaultURL)
        let decryptedData = try vault.open(encryptedData)

        // Import into context (replace mode)
        _ = try importExportService.importBackup(decryptedData, mode: .replace)
    }

    // MARK: - Snapshot

    /// Schedules a snapshot to be taken after a short delay.
    func scheduleSnapshot() {
        snapshotTask?.cancel()
        snapshotTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if !Task.isCancelled {
                try? snapshot()
            }
        }
    }

    /// Immediately takes a snapshot (encrypts and writes the vault).
    /// - Throws: Errors from export, encryption, or file I/O.
    func snapshot() throws {
        // Export to JSON
        let jsonData = try importExportService.exportAll(includeChatHistory: true)

        // Load key (no auth context needed for snapshot, key is already in memory)
        // Note: In production, we'd want to ensure the key is still accessible.
        // For now, we'll load it without auth context; this works because the key
        // is accessible when the app is unlocked.
        let key = try keyStore.loadKey(context: LAContext())
        let vault = CryptoVault(key: key)

        // Encrypt
        let encryptedData = try vault.seal(jsonData)

        // Atomic write
        let tempURL = vaultURL.appendingPathExtension("tmp")
        try encryptedData.write(to: tempURL, options: .atomic)
        try FileManager.default.moveItem(at: tempURL, to: vaultURL)
    }

    // MARK: - Migration

    /// Migrates data from the plaintext store to an encrypted vault.
    /// - Parameter vault: The CryptoVault instance to use for encryption.
    /// - Throws: Errors from export, encryption, or file I/O.
    private func migrateFromPlaintext(vault: CryptoVault) throws {
        guard let migrationContainer else {
            // No migration container provided, assume no data to migrate
            UserDefaults.standard.set(true, forKey: Self.migrationCompletedKey)
            return
        }

        let tempContext = ModelContext(migrationContainer)

        // Export from plaintext context
        let tempImportExport = ImportExportService(context: tempContext)
        let jsonData = try tempImportExport.exportAll(includeChatHistory: true)

        // If there's no data, mark migration complete and return
        // Check if JSON is empty or just contains empty arrays
        if jsonData.isEmpty || jsonData.count < 50 { // Small threshold for empty JSON
            UserDefaults.standard.set(true, forKey: Self.migrationCompletedKey)
            return
        }

        // Encrypt
        let encryptedData = try vault.seal(jsonData)

        // Write vault
        let tempURL = vaultURL.appendingPathExtension("tmp")
        try encryptedData.write(to: tempURL, options: .atomic)
        try FileManager.default.moveItem(at: tempURL, to: vaultURL)

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: Self.migrationCompletedKey)

        // Note: We don't delete the plaintext store here to be safe.
        // The user can delete it manually after confirming migration worked.
        // In a future step, we could add a "clean up" option in settings.
    }

    /// Checks whether migration has been completed.
    var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: Self.migrationCompletedKey)
    }

    /// Deletes the vault file (for disabling encryption).
    func deleteVault() throws {
        if FileManager.default.fileExists(atPath: vaultURL.path) {
            try FileManager.default.removeItem(at: vaultURL)
        }
        UserDefaults.standard.set(false, forKey: Self.migrationCompletedKey)
    }
}
