import CryptoKit
import Foundation

/// Provides AES-GCM encryption/decryption for vault data.
struct CryptoVault {
    private let key: SymmetricKey

    init(key: SymmetricKey) {
        self.key = key
    }

    /// Encrypts the given data using AES-GCM.
    /// - Parameter plaintext: The data to encrypt.
    /// - Returns: The sealed box data (nonce ‖ ciphertext ‖ tag).
    /// - Throws: CryptoKit errors if encryption fails.
    func seal(_ plaintext: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        return sealedBox.combined
    }

    /// Decrypts the given sealed box data.
    /// - Parameter sealed: The sealed box data (nonce ‖ ciphertext ‖ tag).
    /// - Returns: The original plaintext data.
    /// - Throws: CryptoKit errors if decryption fails (e.g., wrong key, tampered data).
    func open(_ sealed: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: sealed)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
