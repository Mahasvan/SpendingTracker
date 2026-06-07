import CryptoKit
import XCTest
@testable import Spending_Tracker

final class CryptoVaultTests: XCTestCase {
    func testSealOpenRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let vault = CryptoVault(key: key)

        let plaintext = Data("Hello, encrypted world!".utf8)
        let sealed = try vault.seal(plaintext)
        let decrypted = try vault.open(sealed)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testSealOpenWithEmptyData() throws {
        let key = SymmetricKey(size: .bits256)
        let vault = CryptoVault(key: key)

        let plaintext = Data()
        let sealed = try vault.seal(plaintext)
        let decrypted = try vault.open(sealed)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testSealOpenWithLargeData() throws {
        let key = SymmetricKey(size: .bits256)
        let vault = CryptoVault(key: key)

        // Create 1MB of data
        let plaintext = Data((0..<1_000_000).map { _ in UInt8.random(in: 0...255) })
        let sealed = try vault.seal(plaintext)
        let decrypted = try vault.open(sealed)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testOpenWithWrongKey() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let vault1 = CryptoVault(key: key1)
        let vault2 = CryptoVault(key: key2)

        let plaintext = Data("Secret data".utf8)
        let sealed = try vault1.seal(plaintext)

        // Attempt to open with wrong key should fail
        XCTAssertThrowsError(try vault2.open(sealed)) { error in
            XCTAssertTrue(error is CryptoKitError, "Expected CryptoKitError, got \(type(of: error))")
        }
    }

    func testOpenWithTamperedData() throws {
        let key = SymmetricKey(size: .bits256)
        let vault = CryptoVault(key: key)

        let plaintext = Data("Secret data".utf8)
        var sealed = try vault.seal(plaintext)

        // Tamper with the sealed data
        sealed[sealed.count / 2] = sealed[sealed.count / 2] ^ 0xFF

        // Attempt to open tampered data should fail
        XCTAssertThrowsError(try vault.open(sealed)) { error in
            XCTAssertTrue(error is CryptoKitError, "Expected CryptoKitError, got \(type(of: error))")
        }
    }

    func testSealProducesDifferentOutputEachTime() throws {
        let key = SymmetricKey(size: .bits256)
        let vault = CryptoVault(key: key)

        let plaintext = Data("Same data".utf8)
        let sealed1 = try vault.seal(plaintext)
        let sealed2 = try vault.seal(plaintext)

        // AES-GCM uses a random nonce, so sealed outputs should differ
        XCTAssertNotEqual(sealed1, sealed2)

        // But both should decrypt to the same plaintext
        XCTAssertEqual(try vault.open(sealed1), plaintext)
        XCTAssertEqual(try vault.open(sealed2), plaintext)
    }
}
