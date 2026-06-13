import Foundation
import VaultSecurity

@MainActor
public struct VaultImportService {
    public enum ImportError: LocalizedError {
        case invalidFileName

        public var errorDescription: String? {
            switch self {
            case .invalidFileName:
                return "The selected file is missing a valid name."
            }
        }
    }

    private let storageService: VaultStorageService
    private let encryptionService: EncryptionService
    private let fileManager: FileManager
    private let encoder = JSONEncoder()

    public init(
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

    public func importFile(
        from sourceURL: URL,
        collectionID: String,
        preferredDisplayName: String? = nil
    ) throws -> VaultItem {
        try ensureTargetCollectionExists(collectionID: collectionID)

        let fileName = resolvedDisplayName(for: sourceURL, preferredDisplayName: preferredDisplayName)
        guard !fileName.isEmpty else {
            throw ImportError.invalidFileName
        }

        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: sourceURL)
        let payload = try encryptionService.encrypt(data: data)

        let itemID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let encryptedFileName = "\(itemID).enc"
        let encryptedFileURL = storageService.filesDirectoryURL.appendingPathComponent(encryptedFileName)
        let payloadData = try encoder.encode(payload)
        try payloadData.write(to: encryptedFileURL, options: .atomic)

        let item = VaultItem(
            id: itemID,
            displayName: fileName,
            collectionId: collectionID,
            encryptedFileName: encryptedFileName,
            size: data.count,
            createdAt: Date()
        )

        do {
            try storageService.appendItem(item)
        } catch {
            if fileManager.fileExists(atPath: encryptedFileURL.path) {
                try? fileManager.removeItem(at: encryptedFileURL)
            }
            throw error
        }

        return item
    }

    private func resolvedDisplayName(for sourceURL: URL, preferredDisplayName: String?) -> String {
        let resourceValues = try? sourceURL.resourceValues(forKeys: [.localizedNameKey, .nameKey])
        let candidates = [
            preferredDisplayName,
            resourceValues?.localizedName,
            resourceValues?.name,
            sourceURL.lastPathComponent,
        ]

        for candidate in candidates {
            let normalizedName = normalizeDisplayName(candidate)
            if !normalizedName.isEmpty {
                return normalizedName
            }
        }

        return ""
    }

    private func normalizeDisplayName(_ candidate: String?) -> String {
        guard let candidate else {
            return ""
        }

        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        let cleaned = trimmed
            .components(separatedBy: CharacterSet(charactersIn: "/:"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return ""
        }

        let pattern = #"^[0-9A-Fa-f]{6,32}[_-](.+)$"#
        if let range = cleaned.range(of: pattern, options: .regularExpression) {
            let suffix = String(cleaned[range]).replacingOccurrences(
                of: #"^[0-9A-Fa-f]{6,32}[_-]"#,
                with: "",
                options: .regularExpression
            )

            if !suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return suffix
            }
        }

        return cleaned
    }

    private func ensureTargetCollectionExists(collectionID: String) throws {
        let collections = try storageService.listCollections()
        guard collections.contains(where: { $0.id == collectionID }) else {
            throw VaultStorageService.StorageError.missingCollection(id: collectionID)
        }
    }
}
