import SwiftUI
import UniformTypeIdentifiers
import VaultStorage

struct FileDetailScreen: View {
    @Environment(AppState.self) private var appState

    let item: VaultItem

    @Environment(\.dismiss) private var dismiss

    @State private var collectionName = "Unknown"
    @State private var fileInteractions = VaultFileInteractionState()
    @State private var errorMessage: String?
    @State private var isShowingDeleteConfirmation = false

    private var originalType: String {
        let fileExtension = URL(fileURLWithPath: item.displayName).pathExtension
        guard !fileExtension.isEmpty else {
            return "Unknown"
        }

        return UTType(filenameExtension: fileExtension)?.localizedDescription ?? fileExtension.uppercased()
    }

    private var fileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Display Name", value: item.displayName)
                LabeledContent("Collection", value: collectionName)
                LabeledContent("File Size", value: fileSize)
                LabeledContent("Created Date", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Original Type", value: originalType)
            } header: {
                SectionHeader(title: "Details")
            }

            Section {
                Button("Open File") {
                    fileInteractions.open(item)
                }
                .disabled(fileInteractions.isPreparingFile)

                Button("Share File") {
                    fileInteractions.share(item)
                }
                .disabled(fileInteractions.isPreparingFile)

                Button("Delete File", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
            } header: {
                SectionHeader(title: "Actions")
            }
        }
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if fileInteractions.isPreparingFile {
                ProgressView("Working…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("File Unavailable", isPresented: Binding(
            get: { (errorMessage ?? fileInteractions.errorMessage) != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                    fileInteractions.errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? fileInteractions.errorMessage ?? "")
        }
        .alert("Delete File?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteFile()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the file from Vault.")
        }
        .fullScreenCover(item: $fileInteractions.previewDocument) { previewDocument in
            QuickLookPreview(
                item: previewDocument.item,
                url: previewDocument.url,
                playbackPosition: appState.playbackPosition(for: previewDocument.item.id),
                onPlaybackPositionChange: { seconds in
                    appState.rememberPlaybackPosition(itemID: previewDocument.item.id, seconds: seconds)
                }
            ) {
                fileInteractions.previewDocument = nil
            }
        }
        .sheet(item: $fileInteractions.shareDocument) { document in
            ActivityView(activityItems: [document.url])
        }
        .task(id: item.collectionId) {
            loadCollectionName()
        }
    }

    private func loadCollectionName() {
        do {
            let storageService = try VaultStorageService(
                appGroupIdentifier: VaultSharedConfiguration.appGroupIdentifier
            )
            collectionName = try storageService.collection(id: item.collectionId)?.name ?? "Unknown"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteFile() {
        do {
            let fileAccessService = try VaultFileAccessService()
            try fileAccessService.delete(item: item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        FileDetailScreen(
            item: VaultItem(
                id: "preview",
                displayName: "Passport.pdf",
                collectionId: VaultStorageService.starterCollectionID,
                encryptedFileName: "preview.enc",
                size: 241_238,
                createdAt: .now
            )
        )
    }
}
