import Foundation
import VaultStorage

struct CollectionSummary: Identifiable {
    let id: String
    let collection: Collection
    let itemCount: Int
    let childCollectionCount: Int

    var name: String { collection.name }
}

enum CollectionsServiceError: LocalizedError, Equatable {
    case maximumDepthReached(maximumDepth: Int)
    case noMoveDestinationsAvailable

    var errorDescription: String? {
        switch self {
        case let .maximumDepthReached(maximumDepth):
            return "Collections can be nested up to \(maximumDepth) levels."
        case .noMoveDestinationsAvailable:
            return "There is no other collection available to move this file into."
        }
    }
}

/// Executes collection-owned storage, hierarchy, import, and mutation operations for collections screens.
struct CollectionsService {
    private let appGroupIdentifier: String
    private let hierarchySettings: CollectionHierarchySettings

    nonisolated init(
        appGroupIdentifier: String = VaultSharedConfiguration.appGroupIdentifier,
        hierarchySettings: CollectionHierarchySettings = CollectionHierarchySettings()
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.hierarchySettings = hierarchySettings
    }

    var maximumHierarchyDepth: Int {
        hierarchySettings.maximumDepth
    }

    func loadRootCollectionSummaries() throws -> [CollectionSummary] {
        try loadCollectionSummaries(parentCollectionID: nil)
    }

    func loadChildCollectionSummaries(parentCollectionID: String) throws -> [CollectionSummary] {
        try loadCollectionSummaries(parentCollectionID: parentCollectionID)
    }

    func createCollection(named name: String, parentCollectionID: String? = nil) throws -> Collection {
        if let parentCollectionID {
            let path = try loadCollectionPath(for: parentCollectionID)
            guard path.count < hierarchySettings.maximumDepth else {
                throw CollectionsServiceError.maximumDepthReached(maximumDepth: hierarchySettings.maximumDepth)
            }
        }

        return try storageService().createCollection(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            name: name,
            parentCollectionId: parentCollectionID
        )
    }

    func loadCollectionDetailContent(for collectionID: String) throws -> CollectionDetailContent {
        let storageService = try storageService()
        guard let collection = try storageService.collection(id: collectionID) else {
            throw VaultStorageService.StorageError.missingCollection(id: collectionID)
        }

        return CollectionDetailContent(
            collection: collection,
            path: try loadCollectionPath(for: collectionID, using: storageService),
            childCollections: try loadCollectionSummaries(parentCollectionID: collectionID, using: storageService),
            items: try loadItems(in: collectionID, using: storageService)
        )
    }

    func loadCollectionPath(for collectionID: String) throws -> [Collection] {
        let storageService = try storageService()
        return try loadCollectionPath(for: collectionID, using: storageService)
    }

    func loadMoveDestinations(excluding excludedCollectionID: String) throws -> [CollectionMoveDestination] {
        let storageService = try storageService()
        let collections = try storageService.listCollections()
        let pathIndex = makePathIndex(for: collections)

        let destinations = collections
            .filter { $0.id != excludedCollectionID }
            .compactMap { collection -> CollectionMoveDestination? in
                guard let path = pathIndex[collection.id] else {
                    return nil
                }

                return CollectionMoveDestination(
                    id: collection.id,
                    collection: collection,
                    depth: path.count,
                    path: path
                )
            }
            .sorted { lhs, rhs in
                if lhs.fullPath != rhs.fullPath {
                    return lhs.fullPath.localizedCaseInsensitiveCompare(rhs.fullPath) == .orderedAscending
                }

                return lhs.collection.createdAt < rhs.collection.createdAt
            }

        guard !destinations.isEmpty else {
            throw CollectionsServiceError.noMoveDestinationsAvailable
        }

        return destinations
    }

    func collection(id: String) throws -> Collection? {
        try storageService().collection(id: id)
    }

    func loadItems(in collectionID: String) throws -> [VaultItem] {
        try loadItems(in: collectionID, using: storageService())
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

    func moveItem(_ item: VaultItem, to collectionID: String) throws -> VaultItem {
        try storageService().moveItem(id: item.id, to: collectionID)
    }

    func deleteItem(_ item: VaultItem) throws {
        let fileDetailService = try FileDetailService()
        try fileDetailService.delete(item: item)
    }

    private func loadCollectionSummaries(
        parentCollectionID: String?,
        using existingStorageService: VaultStorageService? = nil
    ) throws -> [CollectionSummary] {
        let storageService = try existingStorageService ?? self.storageService()
        let collections = try storageService.listCollections()
        let items = try storageService.listItems()

        return collections
            .filter { $0.parentCollectionId == parentCollectionID }
            .map { collection in
                CollectionSummary(
                    id: collection.id,
                    collection: collection,
                    itemCount: items.filter { $0.collectionId == collection.id }.count,
                    childCollectionCount: collections.filter { $0.parentCollectionId == collection.id }.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.name != rhs.name {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

                return lhs.collection.createdAt < rhs.collection.createdAt
            }
    }

    private func loadItems(
        in collectionID: String,
        using storageService: VaultStorageService
    ) throws -> [VaultItem] {
        try storageService.listItems()
            .filter { $0.collectionId == collectionID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func loadCollectionPath(
        for collectionID: String,
        using storageService: VaultStorageService
    ) throws -> [Collection] {
        let collections = try storageService.listCollections()
        let index = Dictionary(uniqueKeysWithValues: collections.map { ($0.id, $0) })

        guard index[collectionID] != nil else {
            throw VaultStorageService.StorageError.missingCollection(id: collectionID)
        }

        var path: [Collection] = []
        var currentID = collectionID

        while let collection = index[currentID] {
            path.append(collection)
            guard let parentCollectionID = collection.parentCollectionId else {
                break
            }

            currentID = parentCollectionID
        }

        return path.reversed()
    }

    private func makePathIndex(for collections: [Collection]) -> [String: [Collection]] {
        let index = Dictionary(uniqueKeysWithValues: collections.map { ($0.id, $0) })
        var pathIndex: [String: [Collection]] = [:]

        for collection in collections {
            var path: [Collection] = []
            var current: Collection? = collection

            while let currentCollection = current {
                path.append(currentCollection)
                current = currentCollection.parentCollectionId.flatMap { index[$0] }
            }

            pathIndex[collection.id] = path.reversed()
        }

        return pathIndex
    }

    private func storageService() throws -> VaultStorageService {
        try VaultStorageService(appGroupIdentifier: appGroupIdentifier)
    }
}
