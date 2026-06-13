import Foundation

public enum VaultSharedConfiguration {
    public static let appGroupIdentifier = "group.james.aworo.Vault"
    public static let keychainAccessGroup = "X2X5Z864A6.james.aworo.VaultShared"
}

public struct Collection: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let createdAt: Date

    public init(id: String, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
    }
}

public struct VaultItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let collectionId: String
    public let encryptedFileName: String
    public let size: Int
    public let createdAt: Date

    public init(
        id: String,
        displayName: String,
        collectionId: String,
        encryptedFileName: String,
        size: Int,
        createdAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.collectionId = collectionId
        self.encryptedFileName = encryptedFileName
        self.size = size
        self.createdAt = createdAt
    }
}

public final class VaultStorageService {
    public static let starterCollectionID = "documents"
    public static let starterCollectionName = "Documents"

    public enum StorageError: LocalizedError, Equatable {
        case duplicateCollection(id: String)
        case duplicateCollectionName(name: String)
        case duplicateItem(id: String)
        case invalidCollectionName
        case missingCollection(id: String)
        case missingItem(id: String)
        case invalidItemsFile

        public var errorDescription: String? {
            switch self {
            case let .duplicateCollection(id):
                return "A collection with id '\(id)' already exists."
            case let .duplicateCollectionName(name):
                return "A collection named '\(name)' already exists."
            case let .duplicateItem(id):
                return "An item with id '\(id)' already exists."
            case .invalidCollectionName:
                return "Collection names cannot be empty."
            case let .missingCollection(id):
                return "No collection with id '\(id)' exists."
            case let .missingItem(id):
                return "No item with id '\(id)' exists."
            case .invalidItemsFile:
                return "The items storage file is invalid."
            }
        }
    }

    public let vaultURL: URL
    public let filesDirectoryURL: URL

    private let collectionsFileURL: URL
    private let itemsFileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let didCreateCollectionsFile: Bool

    public init(
        rootDirectoryURL: URL? = nil,
        appGroupIdentifier: String? = nil,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager

        let baseDirectoryURL: URL
        if let rootDirectoryURL {
            baseDirectoryURL = rootDirectoryURL
        } else if let appGroupIdentifier,
                  let groupContainerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            baseDirectoryURL = groupContainerURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        } else {
            baseDirectoryURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        vaultURL = baseDirectoryURL.appendingPathComponent("Vault", isDirectory: true)
        filesDirectoryURL = vaultURL.appendingPathComponent("files", isDirectory: true)
        collectionsFileURL = vaultURL.appendingPathComponent("collections.json")
        itemsFileURL = vaultURL.appendingPathComponent("items.jsonl")

        didCreateCollectionsFile = !fileManager.fileExists(atPath: collectionsFileURL.path)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try createStorageIfNeeded()
        try migrateLegacyCollectionsIfNeeded()
        try createStarterCollectionIfNeeded()
    }

    public func createCollection(id: String, name: String, createdAt: Date = Date()) throws -> Collection {
        var collections = try listCollections()
        let normalizedName = normalizeCollectionName(name)

        guard !normalizedName.isEmpty else {
            throw StorageError.invalidCollectionName
        }

        guard !collections.contains(where: { $0.id == id }) else {
            throw StorageError.duplicateCollection(id: id)
        }

        guard !collections.contains(where: { $0.name.localizedCaseInsensitiveCompare(normalizedName) == .orderedSame }) else {
            throw StorageError.duplicateCollectionName(name: normalizedName)
        }

        let collection = Collection(id: id, name: normalizedName, createdAt: createdAt)
        collections.append(collection)
        try writeCollections(collections)
        return collection
    }

    public func listCollections() throws -> [Collection] {
        let data = try Data(contentsOf: collectionsFileURL)

        guard !data.isEmpty else {
            return []
        }

        return try decoder.decode([Collection].self, from: data)
    }

    public func appendItem(_ item: VaultItem) throws {
        guard try listCollections().contains(where: { $0.id == item.collectionId }) else {
            throw StorageError.missingCollection(id: item.collectionId)
        }

        guard try !listItems().contains(where: { $0.id == item.id }) else {
            throw StorageError.duplicateItem(id: item.id)
        }

        let data = try encoder.encode(item)

        if fileManager.fileExists(atPath: itemsFileURL.path) {
            var existingData = try Data(contentsOf: itemsFileURL)
            if let lastByte = existingData.last, lastByte != 0x0A {
                existingData.append(0x0A)
            }
            existingData.append(data)
            existingData.append(0x0A)
            try existingData.write(to: itemsFileURL, options: .atomic)
        } else {
            try data.appendingLineFeed().write(to: itemsFileURL)
        }
    }

    public func listItems() throws -> [VaultItem] {
        let data = try Data(contentsOf: itemsFileURL)

        guard !data.isEmpty else {
            return []
        }

        guard let contents = String(data: data, encoding: .utf8) else {
            throw StorageError.invalidItemsFile
        }

        let records = extractItemRecords(from: contents)
        guard !records.isEmpty else {
            throw StorageError.invalidItemsFile
        }

        return try records.map { record in
            guard let lineData = record.data(using: .utf8) else {
                throw StorageError.invalidItemsFile
            }

            return try decoder.decode(VaultItem.self, from: lineData)
        }
    }

    public func deleteItem(id: String) throws {
        var items = try listItems()
        let itemToDelete = items.first { $0.id == id }
        let originalCount = items.count
        items.removeAll { $0.id == id }

        guard items.count != originalCount else {
            throw StorageError.missingItem(id: id)
        }

        try writeItems(items)

        let itemFileURL = filesDirectoryURL.appendingPathComponent(itemToDelete?.encryptedFileName ?? "\(id).enc")
        if fileManager.fileExists(atPath: itemFileURL.path) {
            try fileManager.removeItem(at: itemFileURL)
        }
    }

    public func collection(id: String) throws -> Collection? {
        try listCollections().first(where: { $0.id == id })
    }

    public func item(id: String) throws -> VaultItem? {
        try listItems().first(where: { $0.id == id })
    }

    public func renameCollection(id: String, newName: String) throws -> Collection {
        let normalizedName = normalizeCollectionName(newName)
        guard !normalizedName.isEmpty else {
            throw StorageError.invalidCollectionName
        }

        var collections = try listCollections()
        guard let collectionIndex = collections.firstIndex(where: { $0.id == id }) else {
            throw StorageError.missingCollection(id: id)
        }

        guard !collections.contains(where: {
            $0.id != id && $0.name.localizedCaseInsensitiveCompare(normalizedName) == .orderedSame
        }) else {
            throw StorageError.duplicateCollectionName(name: normalizedName)
        }

        let existingCollection = collections[collectionIndex]
        let updatedCollection = Collection(
            id: existingCollection.id,
            name: normalizedName,
            createdAt: existingCollection.createdAt
        )
        collections[collectionIndex] = updatedCollection
        try writeCollections(collections)
        return updatedCollection
    }

    public func deleteCollection(id: String) throws {
        var collections = try listCollections()
        guard collections.contains(where: { $0.id == id }) else {
            throw StorageError.missingCollection(id: id)
        }

        let itemsToDelete = try listItems().filter { $0.collectionId == id }
        collections.removeAll { $0.id == id }
        try writeCollections(collections)

        let remainingItems = try listItems().filter { $0.collectionId != id }
        try writeItems(remainingItems)

        for item in itemsToDelete {
            let encryptedFileURL = filesDirectoryURL.appendingPathComponent(item.encryptedFileName)
            if fileManager.fileExists(atPath: encryptedFileURL.path) {
                try fileManager.removeItem(at: encryptedFileURL)
            }
        }
    }

    private func createStorageIfNeeded() throws {
        try fileManager.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: filesDirectoryURL, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: collectionsFileURL.path) {
            try writeCollections([])
        }

        if !fileManager.fileExists(atPath: itemsFileURL.path) {
            try Data().write(to: itemsFileURL)
        }
    }

    private func migrateLegacyCollectionsIfNeeded() throws {
        var collections = try listCollections()
        var items = try listItems()
        var needsCollectionRewrite = false
        var needsItemRewrite = false

        if collections.contains(where: { $0.id == "default" }) {
            collections.removeAll { $0.id == "default" }
            collections.append(
                Collection(
                    id: Self.starterCollectionID,
                    name: Self.starterCollectionName,
                    createdAt: Date(timeIntervalSince1970: 0)
                )
            )
            needsCollectionRewrite = true

            items = items.map { item in
                guard item.collectionId == "default" else {
                    return item
                }

                needsItemRewrite = true
                return VaultItem(
                    id: item.id,
                    displayName: item.displayName,
                    collectionId: Self.starterCollectionID,
                    encryptedFileName: item.encryptedFileName,
                    size: item.size,
                    createdAt: item.createdAt
                )
            }
        }

        if needsCollectionRewrite {
            try writeCollections(collections)
        }

        if needsItemRewrite {
            try writeItems(items)
        }
    }

    private func createStarterCollectionIfNeeded() throws {
        guard didCreateCollectionsFile else {
            return
        }

        guard try listCollections().isEmpty else {
            return
        }

        _ = try createCollection(
            id: Self.starterCollectionID,
            name: Self.starterCollectionName,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func writeCollections(_ collections: [Collection]) throws {
        let data = try encoder.encode(collections)
        try data.write(to: collectionsFileURL, options: .atomic)
    }

    private func writeItems(_ items: [VaultItem]) throws {
        guard !items.isEmpty else {
            try Data().write(to: itemsFileURL, options: .atomic)
            return
        }

        let itemData = try items.map(encoder.encode)
        let fileData = itemData.enumerated().reduce(into: Data()) { result, entry in
            result.append(entry.element)
            if entry.offset < itemData.count - 1 {
                result.append(0x0A)
            }
        }

        try fileData.write(to: itemsFileURL, options: .atomic)
    }

    private func normalizeCollectionName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractItemRecords(from contents: String) -> [String] {
        var records: [String] = []
        var currentRecord = ""
        var braceDepth = 0
        var isInsideString = false
        var isEscaping = false

        for character in contents {
            if braceDepth == 0, character.isWhitespace {
                continue
            }

            currentRecord.append(character)

            if isEscaping {
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            if character == "\"" {
                isInsideString.toggle()
                continue
            }

            if isInsideString {
                continue
            }

            switch character {
            case "{":
                braceDepth += 1
            case "}":
                braceDepth -= 1
                if braceDepth == 0 {
                    records.append(currentRecord)
                    currentRecord = ""
                }
            default:
                continue
            }
        }

        return records
    }
}

private extension Data {
    func appendingLineFeed() -> Data {
        var data = self
        data.append(0x0A)
        return data
    }
}
