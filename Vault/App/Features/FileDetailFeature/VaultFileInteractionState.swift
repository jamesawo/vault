import Foundation
import Observation
import VaultStorage

struct PresentedDocument: Identifiable {
    let id = UUID()
    let item: VaultItem
    let url: URL
}

@MainActor
@Observable
final class VaultFileInteractionState {
    var previewDocument: PresentedDocument?
    var shareDocument: PresentedDocument?
    var errorMessage: String?
    var isPreparingFile = false

    func open(_ item: VaultItem) {
        prepare(item) { document in
            self.previewDocument = document
        }
    }

    func share(_ item: VaultItem) {
        prepare(item) { document in
            self.shareDocument = document
        }
    }

    private func prepare(_ item: VaultItem, completion: (PresentedDocument) -> Void) {
        guard !isPreparingFile else {
            return
        }

        isPreparingFile = true
        defer { isPreparingFile = false }

        do {
            let fileAccessService = try VaultFileAccessService()
            let fileURL = try fileAccessService.decryptedFileURL(for: item)
            completion(PresentedDocument(item: item, url: fileURL))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
