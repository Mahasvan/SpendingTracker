import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([
        Transaction.self,
        Category.self,
        PaymentMethod.self,
        Budget.self,
        ChatSession.self,
        ChatMessage.self
    ])

    /// Creates an in-memory container for the encrypted vault.
    /// - Returns: An in-memory ModelContainer.
    static func makeInMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            // Don't seed data - it will come from the vault
            return container
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }

    /// URL of the legacy on-disk SwiftData store, used to detect whether a
    /// pre-encryption plaintext database exists and needs migrating.
    static var legacyStoreURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("default.store", isDirectory: false)
    }

    /// Returns an on-disk container pointing at the legacy plaintext store, but
    /// ONLY if that store already exists. Returns nil for fresh installs so we
    /// never create or seed a plaintext database on disk.
    ///
    /// Note: this container is intentionally NOT seeded — seeding for new users
    /// happens inside the encrypted vault instead.
    static func makeLegacyMigrationContainer() -> ModelContainer? {
        guard FileManager.default.fileExists(atPath: legacyStoreURL.path) else {
            return nil
        }
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }
}
