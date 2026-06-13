import Foundation
import Observation
import VaultStorage

@MainActor
@Observable
final class CollectionFileInteractionState {
    var shareDocument: PresentedDocument?
    var errorMessage: String?
    var isPreparingFile = false

    func share(_ item: VaultItem) {
        guard !isPreparingFile else {
            return
        }

        isPreparingFile = true
        defer { isPreparingFile = false }

        do {
            let fileDetailService = try FileDetailService()
            shareDocument = try fileDetailService.preparedDocument(for: item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Owns collection detail state, hierarchy behavior, file list behavior, and collection-level actions.
@MainActor
@Observable
final class CollectionDetailState {
    var currentCollection: Collection
    var collectionPath: [Collection] = []
    var childCollections: [CollectionSummary] = []
    var items: [VaultItem] = []
    var searchText = ""
    var errorMessage: String?
    var isShowingCollectionInfo = false
    var isShowingRenamePrompt = false
    var renamedCollectionName = ""
    var isShowingDeleteConfirmation = false
    var fileInteractions = CollectionFileInteractionState()
    var itemPendingDeletion: VaultItem?
    var isShowingImportPicker = false
    var isShowingCreateSubcollectionPrompt = false
    var newSubcollectionName = ""
    var itemPendingMove: VaultItem?
    var moveDestinations: [CollectionMoveDestination] = []
    var isShowingMoveDestinationPicker = false

    @ObservationIgnored
    private let service: CollectionsService

    init(collection: Collection, service: CollectionsService = CollectionsService()) {
        currentCollection = collection
        self.service = service
    }

    var filteredChildCollections: [CollectionSummary] {
        guard !searchText.isEmpty else {
            return childCollections
        }

        return childCollections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredItems: [VaultItem] {
        guard !searchText.isEmpty else {
            return items
        }

        return items.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var breadcrumbText: String {
        collectionPath.map(\.name).joined(separator: " > ")
    }

    var maximumHierarchyDepth: Int {
        service.maximumHierarchyDepth
    }

    var currentDepth: Int {
        collectionPath.isEmpty ? 1 : collectionPath.count
    }

    var canCreateSubcollection: Bool {
        currentDepth < maximumHierarchyDepth
    }

    func loadItems() {
        do {
            errorMessage = nil

            let content = try service.loadCollectionDetailContent(for: currentCollection.id)
            currentCollection = content.collection
            collectionPath = content.path
            childCollections = content.childCollections
            items = content.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            do {
                try service.importFiles(from: urls, into: currentCollection.id)
                loadItems()
            } catch {
                errorMessage = error.localizedDescription
            }
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    func beginCreateSubcollection() {
        guard canCreateSubcollection else {
            errorMessage = CollectionsServiceError.maximumDepthReached(maximumDepth: maximumHierarchyDepth).localizedDescription
            return
        }

        newSubcollectionName = ""
        isShowingCreateSubcollectionPrompt = true
    }

    func createSubcollection() {
        do {
            _ = try service.createCollection(named: newSubcollectionName, parentCollectionID: currentCollection.id)
            newSubcollectionName = ""
            loadItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginRenameCollection() {
        renamedCollectionName = currentCollection.name
        isShowingRenamePrompt = true
    }

    func renameCollection() {
        do {
            currentCollection = try service.renameCollection(id: currentCollection.id, newName: renamedCollectionName)
            loadItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCollection(onDeleted: () -> Void) {
        do {
            try service.deleteCollection(id: currentCollection.id)
            onDeleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmDelete(_ item: VaultItem) {
        itemPendingDeletion = item
    }

    func deletePendingItem() {
        guard let itemPendingDeletion else {
            return
        }

        do {
            try service.deleteItem(itemPendingDeletion)
            self.itemPendingDeletion = nil
            loadItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginMove(_ item: VaultItem) {
        do {
            moveDestinations = try service.loadMoveDestinations(excluding: currentCollection.id)
            itemPendingMove = item
            isShowingMoveDestinationPicker = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func movePendingItem(to destination: CollectionMoveDestination) {
        guard let itemPendingMove else {
            return
        }

        do {
            _ = try service.moveItem(itemPendingMove, to: destination.id)
            self.itemPendingMove = nil
            isShowingMoveDestinationPicker = false
            loadItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissMovePicker() {
        isShowingMoveDestinationPicker = false
        itemPendingMove = nil
    }

    func dismissError() {
        errorMessage = nil
    }

    func dismissPendingDeletion() {
        itemPendingDeletion = nil
    }

    func dismissFileError() {
        fileInteractions.errorMessage = nil
    }

    func dismissCollectionInfo() {
        isShowingCollectionInfo = false
    }

    func currentPreviewIndex(preview: CollectionPreviewState?) -> Int? {
        guard let preview,
              preview.collectionID == currentCollection.id else {
            return nil
        }

        return items.firstIndex { $0.id == preview.itemID }
    }

    func openPreview(in appState: AppState, item: VaultItem) {
        appState.presentCollectionPreview(collectionID: currentCollection.id, itemID: item.id)
    }

    func updatePreviewAvailability(in appState: AppState) {
        guard let preview = appState.collectionPreview,
              preview.collectionID == currentCollection.id,
              !items.contains(where: { $0.id == preview.itemID }) else {
            return
        }

        appState.dismissCollectionPreview()
    }
}
