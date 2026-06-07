import CryptoKit
import Foundation
import LocalAuthentication
import SwiftData
@testable import Spending_Tracker

/// In-memory VaultKeyStore for tests; never touches the Keychain or biometrics.
final class MockVaultKeyStore: VaultKeyStore {
    private var key: SymmetricKey?
    var shouldThrowOnLoad = false

    func loadKey(context: LAContext) throws -> SymmetricKey {
        if shouldThrowOnLoad {
            throw KeychainError.keychainStatus(errSecItemNotFound)
        }
        guard let key else {
            throw KeychainError.keychainStatus(errSecItemNotFound)
        }
        return key
    }

    func createKey() throws {
        key = SymmetricKey(size: .bits256)
    }

    func deleteKey() throws {
        key = nil
    }

    var hasKey: Bool { key != nil }
}

@MainActor
enum TestSupport {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Transaction.self,
            Category.self,
            PaymentMethod.self,
            Budget.self,
            ChatSession.self,
            ChatMessage.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func seedDefaults(in container: ModelContainer) {
        DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
    }
}
