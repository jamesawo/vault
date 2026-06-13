import Foundation
import Observation
import VaultStorage

struct PresentedDocument: Identifiable {
    let id = UUID()
    let item: VaultItem
    let url: URL
}

/// Owns file detail screen state, file preparation, and delete workflow for a single vault item.
@MainActor
@Observable
final class FileDetailState {
    let item: VaultItem
    var collectionName = "Unknown"
    var previewDocument: PresentedDocument?
    var shareDocument: PresentedDocument?
    var errorMessage: String?
    var isPreparingFile = false
    var isShowingDeleteConfirmation = false

    @ObservationIgnored
    private let service: FileDetailService?

    init(item: VaultItem, service: FileDetailService? = nil) {
        self.item = item
        self.service = try? service ?? FileDetailService()
    }

    func loadCollectionName() {
        guard let service else {
            errorMessage = "File details are unavailable right now."
            return
        }

        do {
            collectionName = try service.collectionName(for: item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openFile() {
        prepareFile { document in
            previewDocument = document
        }
    }

    func shareFile() {
        prepareFile { document in
            shareDocument = document
        }
    }

    func deleteFile(onDeleted: () -> Void) {
        guard let service else {
            errorMessage = "File details are unavailable right now."
            return
        }

        do {
            try service.delete(item: item)
            onDeleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func prepareFile(_ completion: (PresentedDocument) -> Void) {
        guard !isPreparingFile else {
            return
        }

        guard let service else {
            errorMessage = "File details are unavailable right now."
            return
        }

        isPreparingFile = true
        defer { isPreparingFile = false }

        do {
            completion(try service.preparedDocument(for: item))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
