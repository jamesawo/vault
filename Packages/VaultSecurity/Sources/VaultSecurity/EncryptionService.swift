import CryptoKit
import Foundation

public struct EncryptedPayload: Codable, Equatable, Sendable {
    public let ciphertext: Data
    public let nonce: Data
    public let tag: Data

    public init(ciphertext: Data, nonce: Data, tag: Data) {
        self.ciphertext = ciphertext
        self.nonce = nonce
        self.tag = tag
    }
}

@available(iOS 13.0, macOS 10.15, *)
public final class VaultKeyManager {
    public enum KeyManagerError: LocalizedError, Equatable {
        case unexpectedKeyData
        case unhandledStatus(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .unexpectedKeyData:
                return "The persisted vault encryption key is invalid."
            case let .unhandledStatus(status):
                return "Keychain operation failed with status \(status)."
            }
        }
    }

    private let account: String
    private let service: String
    private let accessGroup: String?

    public init(
        account: String = "VaultEncryptionKey",
        service: String = "james.aworo.Vault",
        accessGroup: String? = nil
    ) {
        self.account = account
        self.service = service
        self.accessGroup = accessGroup
    }

    public func loadOrCreateKey() throws -> SymmetricKey {
        if let existingKey = try loadKey() {
            return existingKey
        }

        let key = SymmetricKey(size: .bits256)
        try storeKey(key)
        return key
    }

    private func loadKey() throws -> SymmetricKey? {
        var query = keychainQuery()
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, data.count == 32 else {
                throw KeyManagerError.unexpectedKeyData
            }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeyManagerError.unhandledStatus(status)
        }
    }

    private func storeKey(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        var query = keychainQuery()
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeyManagerError.unhandledStatus(status)
        }
    }

    private func keychainQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

@available(iOS 13.0, macOS 10.15, *)
public struct EncryptionService {
    public enum EncryptionError: LocalizedError, Equatable {
        case invalidNonce
        case decryptionFailed

        public var errorDescription: String? {
            switch self {
            case .invalidNonce:
                return "The encrypted payload nonce is invalid."
            case .decryptionFailed:
                return "The encrypted payload could not be decrypted."
            }
        }
    }

    private let key: SymmetricKey

    public init() {
        self.key = SymmetricKey(size: .bits256)
    }

    public init(key: SymmetricKey) {
        self.key = key
    }

    public func encrypt(data: Data) throws -> EncryptedPayload {
        let sealedBox = try AES.GCM.seal(data, using: key)

        return EncryptedPayload(
            ciphertext: sealedBox.ciphertext,
            nonce: Data(sealedBox.nonce),
            tag: sealedBox.tag
        )
    }

    public func decrypt(payload: EncryptedPayload) throws -> Data {
        guard let nonce = try? AES.GCM.Nonce(data: payload.nonce) else {
            throw EncryptionError.invalidNonce
        }

        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: payload.ciphertext,
            tag: payload.tag
        )

        do {
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }
}
