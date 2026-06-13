import Foundation
import Observation
import UniformTypeIdentifiers
import VaultStorage

/// Owns home screen state, search, and import-flow decisions for the vault landing experience.
@MainActor
@Observable
final class HomeState {
    var collectionSummaries: [CollectionSummary] = []
    var searchText = ""
    var selectedImportCollectionID: String?
    var isShowingImportCollectionPicker = false
    var isShowingCreateCollectionPrompt = false
    var newCollectionName = ""
    var isImportPickerPresented = false
    var isImporting = false
    var contentErrorMessage: String?
    var importErrorMessage: String?
    var successMessage: String?

    let allowedContentTypes: [UTType] = [.item]

    @ObservationIgnored
    private let collectionsService: CollectionsService

    init(collectionsService: CollectionsService = CollectionsService()) {
        self.collectionsService = collectionsService
    }

    var filteredCollectionSummaries: [CollectionSummary] {
        guard !searchText.isEmpty else {
            return collectionSummaries
        }

        return collectionSummaries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    func startImportFlow() {
        if collectionSummaries.isEmpty {
            newCollectionName = ""
            isShowingCreateCollectionPrompt = true
            return
        }

        isShowingImportCollectionPicker = true
    }

    func chooseImportCollection(_ collectionID: String) {
        selectedImportCollectionID = collectionID
        isImportPickerPresented = true
    }

    func cancelImportFlow() {
        selectedImportCollectionID = nil
        isShowingImportCollectionPicker = false
    }

    func dismissImportError() {
        importErrorMessage = nil
    }

    func dismissContentError() {
        contentErrorMessage = nil
    }

    func dismissSuccessMessage() {
        successMessage = nil
    }

    func loadContent() {
        do {
            contentErrorMessage = nil
            collectionSummaries = try collectionsService
                .loadRootCollectionSummaries()
                .sorted { lhs, rhs in
                    if lhs.itemCount != rhs.itemCount {
                        return lhs.itemCount > rhs.itemCount
                    }

                    if lhs.childCollectionCount != rhs.childCollectionCount {
                        return lhs.childCollectionCount > rhs.childCollectionCount
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

    func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let selectedImportCollectionID else {
                importErrorMessage = "Choose a collection before importing."
                return
            }

            guard !urls.isEmpty else {
                importErrorMessage = "Choose at least one file to import."
                return
            }

            Task {
                await importFiles(from: urls, collectionID: selectedImportCollectionID)
                self.selectedImportCollectionID = nil
            }
        case let .failure(error):
            importErrorMessage = error.localizedDescription
            selectedImportCollectionID = nil
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
        let collection = try collectionsService.createCollection(named: name)
        loadContent()
        return collection
    }

    func createCollectionAndContinueImport() {
        do {
            let collection = try createCollection(named: newCollectionName)
            newCollectionName = ""
            selectedImportCollectionID = collection.id
            isImportPickerPresented = true
        } catch {
            contentErrorMessage = error.localizedDescription
        }
    }
}
