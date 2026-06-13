import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers
import VaultStorage

@MainActor
final class ShareExtensionState: ObservableObject {
    private struct SharedFile {
        let url: URL
        let displayName: String?
    }

    private let extensionContext: NSExtensionContext?
    private let storageService: VaultStorageService

    @Published var collections: [Collection] = []
    @Published var isLoading = true
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isShowingCreateCollectionPrompt = false
    @Published var newCollectionName = ""

    init(
        extensionContext: NSExtensionContext?,
        storageService: VaultStorageService? = nil
    ) {
        self.extensionContext = extensionContext
        self.storageService = storageService ?? Self.makeStorageService()

        Task {
            await loadCollections()
        }
    }

    func loadCollections() async {
        isLoading = true
        defer { isLoading = false }

        do {
            collections = try storageService.listCollections()
                .sorted {
                    if $0.name != $1.name {
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    return $0.createdAt < $1.createdAt
                }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importIntoCollection(_ collectionID: String) async {
        guard !isImporting else {
            return
        }

        isImporting = true
        errorMessage = nil

        defer { isImporting = false }

        do {
            let sharedFiles = try await resolveSharedFiles()
            let importService = try VaultImportService(storageService: storageService)
            var importedItems: [VaultItem] = []

            for sharedFile in sharedFiles {
                let item = try importService.importFile(
                    from: sharedFile.url,
                    collectionID: collectionID,
                    preferredDisplayName: sharedFile.displayName
                )
                importedItems.append(item)
            }

            if importedItems.count == 1, let item = importedItems.first {
                successMessage = "Imported \(item.displayName)."
            } else {
                successMessage = "Imported \(importedItems.count) files."
            }

            Task {
                try await Task.sleep(for: .milliseconds(500))
                completeRequest()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createCollectionAndContinueImport() async {
        do {
            let collection = try storageService.createCollection(
                id: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
                name: newCollectionName
            )
            newCollectionName = ""
            collections.append(collection)
            collections.sort {
                if $0.name != $1.name {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.createdAt < $1.createdAt
            }
            await importIntoCollection(collection.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        extensionContext?.cancelRequest(withError: error)
    }

    private static func makeStorageService() -> VaultStorageService {
        do {
            return try VaultStorageService(appGroupIdentifier: VaultSharedConfiguration.appGroupIdentifier)
        } catch {
            fatalError("VaultStorageService could not be created: \(error.localizedDescription)")
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [])
    }

    private func resolveSharedFiles() async throws -> [SharedFile] {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            throw ShareError.noSharedItem
        }

        var sharedFiles: [SharedFile] = []

        for item in inputItems {
            for provider in item.attachments ?? [] {
                if let sharedFile = try await loadFile(from: provider) {
                    sharedFiles.append(sharedFile)
                }
            }
        }

        guard !sharedFiles.isEmpty else {
            throw ShareError.noSupportedAttachment
        }

        return sharedFiles
    }

    private func loadFile(from itemProvider: NSItemProvider) async throws -> SharedFile? {
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
            return try await loadFileURL(from: itemProvider, typeIdentifier: UTType.item.identifier)
        }

        if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let sharedFile = try await loadTextURL(from: itemProvider) {
            return sharedFile
        }

        return nil
    }

    private func loadFileURL(from itemProvider: NSItemProvider, typeIdentifier: String) async throws -> SharedFile {
        try await withCheckedThrowingContinuation { continuation in
            itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url else {
                    continuation.resume(throwing: ShareError.noSupportedAttachment)
                    return
                }

                let destinationDirectory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("VaultShareImport", isDirectory: true)

                do {
                    try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
                    let preferredName = url.lastPathComponent.isEmpty ? UUID().uuidString : url.lastPathComponent
                    let destinationURL = destinationDirectory.appendingPathComponent("\(UUID().uuidString)-\(preferredName)")

                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }

                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    let displayName = itemProvider.suggestedName ?? preferredName
                    continuation.resume(returning: SharedFile(url: destinationURL, displayName: displayName))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadTextURL(from itemProvider: NSItemProvider) async throws -> SharedFile? {
        try await withCheckedThrowingContinuation { continuation in
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let item else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let text: String
                    switch item {
                    case let string as String:
                        text = string
                    case let data as Data:
                        guard let decodedString = String(data: data, encoding: .utf8) else {
                            throw ShareError.noSupportedAttachment
                        }
                        text = decodedString
                    case let url as URL:
                        continuation.resume(returning: SharedFile(
                            url: url,
                            displayName: itemProvider.suggestedName ?? url.lastPathComponent
                        ))
                        return
                    default:
                        throw ShareError.noSupportedAttachment
                    }

                    let destinationDirectory = FileManager.default.temporaryDirectory
                        .appendingPathComponent("VaultShareImport", isDirectory: true)
                    try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
                    let displayName = itemProvider.suggestedName ?? "Shared Text.txt"
                    let fileURL = destinationDirectory.appendingPathComponent("\(UUID().uuidString).txt")
                    try text.data(using: .utf8)?.write(to: fileURL)
                    continuation.resume(returning: SharedFile(url: fileURL, displayName: displayName))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension ShareExtensionState {
    enum ShareError: LocalizedError {
        case noSharedItem
        case noSupportedAttachment

        var errorDescription: String? {
            switch self {
            case .noSharedItem:
                return "No shared item was received."
            case .noSupportedAttachment:
                return "The shared item could not be imported."
            }
        }
    }
}
