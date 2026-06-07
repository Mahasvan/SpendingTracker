import CryptoKit
import Foundation
import LocalAuthentication
import SwiftData

enum VaultCoordinatorError: LocalizedError {
    case vaultLocked

    var errorDescription: String? {
        switch self {
        case .vaultLocked:
            return "The vault is locked. Unlock the app before saving."
        }
    }
}

/// Coordinates vault encryption/decryption and data loading.
@MainActor
final class VaultCoordinator {
    private let keyStore: VaultKeyStore
    private let context: ModelContext
    private let vaultURL: URL
    private let importExportService: ImportExportService
    private let migrationContainer: ModelContainer?

    /// The encryption key, cached in memory after a successful unlock so that
    /// snapshots don't re-prompt for biometrics on every save.
    private var cachedKey: SymmetricKey?

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

    /// Whether the vault has been unlocked (key cached) in this session.
    var isUnlocked: Bool { cachedKey != nil }

    // MARK: - Load

    /// Loads the vault into the in-memory context.
    /// - Parameter authContext: The LAContext from biometric authentication.
    /// - Throws: Errors from key loading, decryption, or import.
    func loadVault(authContext: LAContext) throws {
        // Ensure key exists
        if !keyStore.hasKey {
            try keyStore.createKey()
        }

        // Load key once (this is the only call that may prompt for biometrics)
        // and cache it for the rest of the session so snapshots don't re-prompt.
        let key = try keyStore.loadKey(context: authContext)
        cachedKey = key
        let vault = CryptoVault(key: key)

        // Check if vault file exists
        if !FileManager.default.fileExists(atPath: vaultURL.path) {
            // First run: no vault yet, try migration from plaintext store.
            try migrateFromPlaintext(vault: vault)
            // If still nothing was loaded (brand-new user), seed defaults into
            // the in-memory store and write the first encrypted snapshot.
            if try isContextEmpty() {
                DefaultDataSeeder.seedIfNeeded(in: context)
                try context.save()
                try snapshot()
            }
            return
        }

        // Decrypt vault
        let encryptedData = try Data(contentsOf: vaultURL)
        let decryptedData = try vault.open(encryptedData)

        // Import into context (replace mode)
        _ = try importExportService.importBackup(decryptedData, mode: .replace)
    }

    private func isContextEmpty() throws -> Bool {
        let categoryCount = try context.fetchCount(FetchDescriptor<Category>())
        let txCount = try context.fetchCount(FetchDescriptor<Transaction>())
        return categoryCount == 0 && txCount == 0
    }

    // MARK: - Snapshot

    /// Schedules a snapshot to be taken after a short delay.
    func scheduleSnapshot() {
        snapshotTask?.cancel()
        snapshotTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            guard let self, !Task.isCancelled else { return }
            try? self.snapshot()
        }
    }

    /// Immediately takes a snapshot (encrypts and writes the vault).
    /// Uses the in-memory cached key, so it never prompts for biometrics.
    /// - Throws: `VaultCoordinatorError.vaultLocked` if called before unlock,
    ///   or errors from export, encryption, or file I/O.
    func snapshot() throws {
        // Use the cached key. If the vault was never unlocked, refuse to write
        // rather than prompting for biometrics from a background/save context.
        guard let key = cachedKey else {
            throw VaultCoordinatorError.vaultLocked
        }

        // Export to JSON
        let jsonData = try importExportService.exportAll(includeChatHistory: true)

        let vault = CryptoVault(key: key)
        let encryptedData = try vault.seal(jsonData)

        // Atomic write that overwrites any existing vault file.
        try encryptedData.write(to: vaultURL, options: .atomic)
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
