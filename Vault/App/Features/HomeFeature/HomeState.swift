import Foundation
import Observation
import UniformTypeIdentifiers
import VaultStorage

struct CollectionSummary: Identifiable {
    let id: String
    let collection: Collection
    let itemCount: Int

    var name: String { collection.name }
}

@MainActor
@Observable
final class HomeState {
    var collectionSummaries: [CollectionSummary] = []
    var searchText = ""
    var isImportPickerPresented = false
    var isImporting = false
    var contentErrorMessage: String?
    var importErrorMessage: String?
    var successMessage: String?

    let allowedContentTypes: [UTType] = [.item]

    var filteredCollectionSummaries: [CollectionSummary] {
        guard !searchText.isEmpty else {
            return collectionSummaries
        }

        return collectionSummaries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadContent() {
        do {
            contentErrorMessage = nil
            let storageService = try VaultStorageService(
                appGroupIdentifier: VaultSharedConfiguration.appGroupIdentifier
            )
            let collections = try storageService.listCollections()
            let items = try storageService.listItems()

            collectionSummaries = collections
                .map { collection in
                    CollectionSummary(
                        id: collection.id,
                        collection: collection,
                        itemCount: items.filter { $0.collectionId == collection.id }.count
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.itemCount != rhs.itemCount {
                        return lhs.itemCount > rhs.itemCount
                    }

                    if lhs.name != rhs.name {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }

                    return lhs.collection.createdAt < rhs.collection.createdAt
                }
        } catch {
            contentErrorMessage = error.localizedDescription
        }
    }

    func importFiles(from urls: [URL], collectionID: String) async {
        guard !isImporting else {
            return
        }

        isImporting = true
        importErrorMessage = nil
        successMessage = nil

        defer {
            isImporting = false
        }

        do {
            let importService = try VaultImportService()
            var importedItems: [VaultItem] = []

            for url in urls {
                let item = try importService.importFile(from: url, collectionID: collectionID)
                importedItems.append(item)
            }

            loadContent()

            if importedItems.count == 1, let item = importedItems.first {
                successMessage = "Imported \(item.displayName)."
            } else {
                successMessage = "Imported \(importedItems.count) files."
            }
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    func createCollection(named name: String) throws -> Collection {
        let storageService = try VaultStorageService(
            appGroupIdentifier: VaultSharedConfiguration.appGroupIdentifier
        )
        let collection = try storageService.createCollection(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            name: name
        )
        loadContent()
        return collection
    }
}
