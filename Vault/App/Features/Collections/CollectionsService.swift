import Foundation
import VaultStorage

struct CollectionSummary: Identifiable {
    let id: String
    let collection: Collection
    let itemCount: Int

    var name: String { collection.name }
}

/// Executes collection-owned storage, import, and mutation operations for collections screens.
struct CollectionsService {
    private let appGroupIdentifier: String

    nonisolated init(appGroupIdentifier: String = VaultSharedConfiguration.appGroupIdentifier) {
        self.appGroupIdentifier = appGroupIdentifier
    }

    func loadCollectionSummaries() throws -> [CollectionSummary] {
        let storageService = try storageService()
        let items = try storageService.listItems()

        return try storageService.listCollections()
            .map { collection in
                CollectionSummary(
                    id: collection.id,
                    collection: collection,
                    itemCount: items.filter { $0.collectionId == collection.id }.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.name != rhs.name {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

                return lhs.collection.createdAt < rhs.collection.createdAt
            }
    }

    func createCollection(named name: String) throws -> Collection {
        try storageService().createCollection(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            name: name
        )
    }

    func collection(id: String) throws -> Collection? {
        try storageService().collection(id: id)
    }

    func loadItems(in collectionID: String) throws -> [VaultItem] {
        try storageService().listItems()
            .filter { $0.collectionId == collectionID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func importFiles(from urls: [URL], into collectionID: String) throws {
        let importService = try VaultImportService()

        for url in urls {
            _ = try importService.importFile(from: url, collectionID: collectionID)
        }
    }

    func renameCollection(id: String, newName: String) throws -> Collection {
        try storageService().renameCollection(id: id, newName: newName)
    }

    func deleteCollection(id: String) throws {
        try storageService().deleteCollection(id: id)
    }

    func deleteItem(_ item: VaultItem) throws {
        let fileDetailService = try FileDetailService()
        try fileDetailService.delete(item: item)
    }

    private func storageService() throws -> VaultStorageService {
        try VaultStorageService(appGroupIdentifier: appGroupIdentifier)
    }
}
