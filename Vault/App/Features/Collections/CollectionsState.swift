import Foundation
import Observation

/// Owns the collections list state and user intents for collection management.
@MainActor
@Observable
final class CollectionsState {
    var collectionSummaries: [CollectionSummary] = []
    var searchText = ""
    var errorMessage: String?
    var placeholderMessage: String?
    var isShowingCreateCollectionPrompt = false
    var newCollectionName = ""

    @ObservationIgnored
    private let service: CollectionsService

    init(service: CollectionsService = CollectionsService()) {
        self.service = service
    }

    var filteredCollections: [CollectionSummary] {
        guard !searchText.isEmpty else {
            return collectionSummaries
        }

        return collectionSummaries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func loadCollections() {
        do {
            errorMessage = nil
            collectionSummaries = try service.loadCollectionSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginCreateCollection() {
        newCollectionName = ""
        isShowingCreateCollectionPrompt = true
    }

    func createCollection() {
        do {
            _ = try service.createCollection(named: newCollectionName)
            loadCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showPlaceholder(_ message: String) {
        placeholderMessage = message
    }

    func dismissError() {
        errorMessage = nil
    }

    func dismissPlaceholder() {
        placeholderMessage = nil
    }
}
