import Foundation
import Testing
@testable import VaultStorage

struct VaultStorageServiceTests {
    @Test
    func createsStorageLayoutOnInitialization() throws {
        let rootDirectoryURL = try makeTemporaryDirectory()

        _ = try VaultStorageService(rootDirectoryURL: rootDirectoryURL)

        let vaultURL = rootDirectoryURL.appendingPathComponent("Vault", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: vaultURL.path))
        #expect(FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent("files").path))
        #expect(FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent("collections.json").path))
        #expect(FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent("items.jsonl").path))
    }

    @Test
    func createsAndListsCollections() throws {
        let service = try VaultStorageService(rootDirectoryURL: try makeTemporaryDirectory())

        let collection = try service.createCollection(
            id: "records",
            name: "Records",
            createdAt: Date(timeIntervalSince1970: 1_781_092_800)
        )
        let collections = try service.listCollections()

        #expect(collections.contains(collection))
        #expect(collection.parentCollectionId == nil)
        #expect(collection.updatedAt == collection.createdAt)
        #expect(collections.contains(where: { $0.id == VaultStorageService.starterCollectionID }))
    }

    @Test
    func createsSubCollectionsAndAllowsDuplicateNamesUnderDifferentParents() throws {
        let service = try VaultStorageService(rootDirectoryURL: try makeTemporaryDirectory())
        let family = try service.createCollection(id: "family", name: "Family")
        let finance = try service.createCollection(id: "finance", name: "Finance")

        let fatherHousing = try service.createCollection(id: "family-housing", name: "Housing", parentCollectionId: family.id)
        let financeHousing = try service.createCollection(id: "finance-housing", name: "Housing", parentCollectionId: finance.id)

        #expect(fatherHousing.parentCollectionId == family.id)
        #expect(financeHousing.parentCollectionId == finance.id)
    }

    @Test
    func appendsListsAndDeletesItems() throws {
        let service = try VaultStorageService(rootDirectoryURL: try makeTemporaryDirectory())
        _ = try service.createCollection(id: "records", name: "Records")

        let item = VaultItem(
            id: "a8f23d91",
            displayName: "Document.pdf",
            collectionId: "records",
            encryptedFileName: "a8f23d91.enc",
            size: 241_238,
            createdAt: Date(timeIntervalSince1970: 1_781_092_800)
        )

        try service.appendItem(item)
        #expect(try service.listItems() == [item])

        try service.deleteItem(id: item.id)
        #expect(try service.listItems().isEmpty)
    }

    @Test
    func readsItemsWhenAdjacentJsonObjectsWereWrittenWithoutNewlineSeparator() throws {
        let rootDirectoryURL = try makeTemporaryDirectory()
        let service = try VaultStorageService(rootDirectoryURL: rootDirectoryURL)
        _ = try service.createCollection(id: "secondary", name: "Secondary")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let firstItem = VaultItem(
            id: "first",
            displayName: "first.txt",
            collectionId: VaultStorageService.starterCollectionID,
            encryptedFileName: "first.enc",
            size: 1,
            createdAt: Date(timeIntervalSince1970: 1_781_092_800)
        )
        let secondItem = VaultItem(
            id: "second",
            displayName: "second.txt",
            collectionId: "secondary",
            encryptedFileName: "second.enc",
            size: 2,
            createdAt: Date(timeIntervalSince1970: 1_781_092_801)
        )

        let itemsURL = rootDirectoryURL
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent("items.jsonl")
        let malformedData = try encoder.encode(firstItem) + encoder.encode(secondItem)
        try malformedData.write(to: itemsURL)

        #expect(try service.listItems() == [firstItem, secondItem])
    }

    @Test
    func rejectsItemsForMissingCollections() throws {
        let service = try VaultStorageService(rootDirectoryURL: try makeTemporaryDirectory())
        let item = VaultItem(
            id: "a8f23d91",
            displayName: "Document.pdf",
            collectionId: "records",
            encryptedFileName: "a8f23d91.enc",
            size: 241_238,
            createdAt: Date(timeIntervalSince1970: 1_781_092_800)
        )

        #expect(throws: VaultStorageService.StorageError.missingCollection(id: "records")) {
            try service.appendItem(item)
        }
    }

    @Test
    func migratesLegacyDefaultCollectionToDocuments() throws {
        let rootDirectoryURL = try makeTemporaryDirectory()
        let vaultURL = rootDirectoryURL.appendingPathComponent("Vault", isDirectory: true)
        let collectionsURL = vaultURL.appendingPathComponent("collections.json")
        let itemsURL = vaultURL.appendingPathComponent("items.jsonl")
        let filesURL = vaultURL.appendingPathComponent("files", isDirectory: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        try FileManager.default.createDirectory(at: filesURL, withIntermediateDirectories: true)
        try Data(#"[{"id":"default","name":"Default"}]"#.utf8).write(to: collectionsURL)

        let item = VaultItem(
            id: "a8f23d91",
            displayName: "Document.pdf",
            collectionId: "default",
            encryptedFileName: "a8f23d91.enc",
            size: 241_238,
            createdAt: Date(timeIntervalSince1970: 1_781_092_800)
        )
        try encoder.encode(item).write(to: itemsURL)

        let service = try VaultStorageService(rootDirectoryURL: rootDirectoryURL)
        let collections = try service.listCollections()
        let items = try service.listItems()

        #expect(!collections.contains(where: { $0.id == "default" }))
        #expect(collections.contains(where: { $0.id == VaultStorageService.starterCollectionID }))
        #expect(items.map(\.collectionId) == [VaultStorageService.starterCollectionID])
    }

    @Test
    func createsOnlyOneStarterCollectionOnFirstRun() throws {
        let service = try VaultStorageService(rootDirectoryURL: try makeTemporaryDirectory())
        let collections = try service.listCollections()

        #expect(collections.count == 1)
        #expect(collections.first?.id == VaultStorageService.starterCollectionID)
        #expect(collections.first?.name == VaultStorageService.starterCollectionName)
    }

    @Test
    func doesNotRecreateDeletedStarterCollectionOnRelaunch() throws {
        let rootDirectoryURL = try makeTemporaryDirectory()
        let service = try VaultStorageService(rootDirectoryURL: rootDirectoryURL)
        try service.deleteCollection(id: VaultStorageService.starterCollectionID)

        let reloadedService = try VaultStorageService(rootDirectoryURL: rootDirectoryURL)

        #expect(try reloadedService.listCollections().isEmpty)
    }

    @Test
    func renamesCollectionAndRejectsDuplicateNames() throws {
        let service = try VaultStorageService(rootDirectoryURL: try makeTemporaryDirectory())
        let createdCollection = try service.createCollection(id: "alpha", name: "Alpha")
        let beta = try service.createCollection(id: "beta", name: "Beta")
        let childAlpha = try service.createCollection(id: "alpha-child", name: "Alpha Child", parentCollectionId: createdCollection.id)
        _ = try service.createCollection(id: "alpha-sibling", name: "Beta Child", parentCollectionId: createdCollection.id)
        _ = try service.createCollection(id: "beta-child", name: "Beta Child", parentCollectionId: beta.id)

        let renamedCollection = try service.renameCollection(id: createdCollection.id, newName: "Gamma")

        #expect(renamedCollection.name == "Gamma")
        #expect(try service.collection(id: createdCollection.id)?.name == "Gamma")
        #expect(throws: VaultStorageService.StorageError.duplicateCollectionName(name: "Beta")) {
            try service.renameCollection(id: createdCollection.id, newName: "Beta")
        }
        #expect(throws: VaultStorageService.StorageError.duplicateCollectionName(name: "Beta Child")) {
            try service.renameCollection(id: childAlpha.id, newName: "Beta Child")
        }

        let renamedChild = try service.renameCollection(id: childAlpha.id, newName: "Alpha")
        #expect(renamedChild.parentCollectionId == createdCollection.id)
    }

    @Test
    func blocksDeletingNonEmptyCollectionsAndAllowsDeletingEmptyCollections() throws {
        let service = try VaultStorageService(rootDirectoryURL: try makeTemporaryDirectory())
        let alpha = try service.createCollection(id: "alpha", name: "Alpha")
        let child = try service.createCollection(id: "child", name: "Child", parentCollectionId: alpha.id)

        let item = VaultItem(
            id: "alpha-file",
            displayName: "Attachment.pdf",
            collectionId: "alpha",
            encryptedFileName: "alpha-file.enc",
            size: 1_024,
            createdAt: Date(timeIntervalSince1970: 1_781_092_800)
        )

        try service.appendItem(item)

        #expect(throws: VaultStorageService.StorageError.collectionNotEmpty(id: "alpha")) {
            try service.deleteCollection(id: "alpha")
        }

        try service.deleteCollection(id: child.id)
        #expect(try service.collection(id: child.id) == nil)
    }

    @Test
    func movesItemsBetweenCollectionsWithoutDuplicatingThem() throws {
        let service = try VaultStorageService(rootDirectoryURL: try makeTemporaryDirectory())
        _ = try service.createCollection(id: "alpha", name: "Alpha")
        _ = try service.createCollection(id: "beta", name: "Beta")

        let item = VaultItem(
            id: "alpha-file",
            displayName: "Attachment.pdf",
            collectionId: "alpha",
            encryptedFileName: "alpha-file.enc",
            size: 1_024,
            createdAt: Date(timeIntervalSince1970: 1_781_092_800)
        )

        try service.appendItem(item)
        let movedItem = try service.moveItem(id: item.id, to: "beta")
        let items = try service.listItems()

        #expect(movedItem.collectionId == "beta")
        #expect(items.count == 1)
        #expect(items.first?.collectionId == "beta")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}
