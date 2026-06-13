import Foundation
import Observation
import VaultStorage

/// Owns collection detail state, file list behavior, and collection-level actions.
@MainActor
@Observable
final class CollectionDetailState {
    var currentCollection: Collection
    var items: [VaultItem] = []
    var searchText = ""
    var errorMessage: String?
    var isShowingCollectionInfo = false
    var isShowingRenamePrompt = false
    var renamedCollectionName = ""
    var isShowingDeleteConfirmation = false
    var fileInteractions = VaultFileInteractionState()
    var itemPendingDeletion: VaultItem?
    var isShowingImportPicker = false

    @ObservationIgnored
    private let service: CollectionsService

    init(collection: Collection, service: CollectionsService = CollectionsService()) {
        currentCollection = collection
        self.service = service
    }

    var filteredItems: [VaultItem] {
        guard !searchText.isEmpty else {
            return items
        }

        return items.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    func loadItems() {
        do {
            errorMessage = nil

            if let refreshedCollection = try service.collection(id: currentCollection.id) {
                currentCollection = refreshedCollection
            }

            items = try service.loadItems(in: currentCollection.id)
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

    func beginRenameCollection() {
        renamedCollectionName = currentCollection.name
        isShowingRenamePrompt = true
    }

    func renameCollection() {
        do {
            currentCollection = try service.renameCollection(id: currentCollection.id, newName: renamedCollectionName)
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
