import CryptoKit
import Foundation
import LocalAuthentication

/// Manages the vault encryption key in the Keychain with biometric protection.
protocol VaultKeyStore {
    /// Loads the encryption key from the Keychain.
    /// - Parameter context: The LAContext from biometric authentication.
    /// - Returns: The symmetric key.
    /// - Throws: Keychain errors if the key is missing or authentication fails.
    func loadKey(context: LAContext) throws -> SymmetricKey

    /// Creates a new encryption key and stores it in the Keychain.
    /// - Throws: Keychain errors if storage fails.
    func createKey() throws

    /// Deletes the encryption key from the Keychain.
    /// - Throws: Keychain errors if deletion fails.
    func deleteKey() throws

    /// Checks whether a key exists in the Keychain.
    var hasKey: Bool { get }
}

/// Keychain-based implementation of VaultKeyStore.
/// The key is protected with user presence (Touch ID or device password).
final class KeychainVaultKeyStore: VaultKeyStore {
    private static let service = "com.spendingtracker.vault"
    private static let account = "encryption-key"

    func loadKey(context: LAContext) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let keyData = result as? Data else {
            throw KeychainError(status: status)
        }

        return SymmetricKey(data: keyData)
    }

    func createKey() throws {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Add access control requiring user presence
        var accessError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &accessError
        ) else {
            if let error = accessError?.takeRetainedValue() as Error {
                throw error
            }
            throw KeychainError(status: errSecInternalError)
        }

        let queryWithAccess: [String: Any] = query.merging([
            kSecAttrAccessControl as String: accessControl
        ]) { _, new in new }

        let status = SecItemAdd(queryWithAccess as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }

    func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    var hasKey: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

enum KeychainError: LocalizedError {
    case status(OSStatus)

    var errorDescription: String? {
        switch status {
        case errSecItemNotFound:
            return "Key not found in Keychain"
        case errSecUserCanceled:
            return "Authentication canceled by user"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecInteractionNotAllowed:
            return "User interaction not allowed"
        default:
            return "Keychain error: \(status)"
        }
    }
}
