import Foundation
import VaultSecurity
import VaultStorage

struct VaultFileAccessService {
    private let storageService: VaultStorageService
    private let encryptionService: EncryptionService
    private let fileManager: FileManager
    private let decoder = JSONDecoder()

    init(
        storageService: VaultStorageService? = nil,
        keyManager: VaultKeyManager = VaultKeyManager(
            accessGroup: VaultSharedConfiguration.keychainAccessGroup
        ),
        fileManager: FileManager = .default
    ) throws {
        self.storageService = try storageService ?? VaultStorageService(
            appGroupIdentifier: VaultSharedConfiguration.appGroupIdentifier
        )
        self.encryptionService = try EncryptionService(key: keyManager.loadOrCreateKey())
        self.fileManager = fileManager
    }

    func decryptedFileURL(for item: VaultItem) throws -> URL {
        let encryptedFileURL = storageService.filesDirectoryURL.appendingPathComponent(item.encryptedFileName)
        let payloadData = try Data(contentsOf: encryptedFileURL)
        let payload = try decoder.decode(EncryptedPayload.self, from: payloadData)
        let decryptedData = try encryptionService.decrypt(payload: payload)

        let previewDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent("VaultPreview", isDirectory: true)
        try fileManager.createDirectory(at: previewDirectoryURL, withIntermediateDirectories: true)

        let sanitizedFileName = sanitizeFileName(item.displayName, fallbackID: item.id)
        let destinationURL = previewDirectoryURL.appendingPathComponent("\(item.id)-\(sanitizedFileName)")

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try decryptedData.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    func delete(item: VaultItem) throws {
        try storageService.deleteItem(id: item.id)
    }

    private func sanitizeFileName(_ fileName: String, fallbackID: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallbackID
        }

        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let cleaned = trimmed.components(separatedBy: invalidCharacters).joined(separator: "-")
        return cleaned.isEmpty ? fallbackID : cleaned
    }
}
