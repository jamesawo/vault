import SwiftUI
import UniformTypeIdentifiers
import VaultStorage

/// Renders file metadata and forwards open, share, and delete actions to `FileDetailState`.
struct FileDetailScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var state: FileDetailState

    init(item: VaultItem) {
        _state = State(initialValue: FileDetailState(item: item))
    }

    private var originalType: String {
        let fileExtension = URL(fileURLWithPath: state.item.displayName).pathExtension
        guard !fileExtension.isEmpty else {
            return "Unknown"
        }

        return UTType(filenameExtension: fileExtension)?.localizedDescription ?? fileExtension.uppercased()
    }

    private var fileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(state.item.size), countStyle: .file)
    }

    var body: some View {
        @Bindable var state = state

        List {
            Section {
                LabeledContent("Display Name", value: state.item.displayName)
                LabeledContent("Collection", value: state.collectionName)
                LabeledContent("File Size", value: fileSize)
                LabeledContent("Created Date", value: state.item.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Original Type", value: originalType)
            } header: {
                FileDetailSectionHeader(title: "Details")
            }

            Section {
                Button("Open File") {
                    state.openFile()
                }
                .disabled(state.isPreparingFile)

                Button("Share File") {
                    state.shareFile()
                }
                .disabled(state.isPreparingFile)

                Button("Delete File", role: .destructive) {
                    state.isShowingDeleteConfirmation = true
                }
            } header: {
                FileDetailSectionHeader(title: "Actions")
            }
        }
        .navigationTitle(state.item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if state.isPreparingFile {
                ProgressView("Working…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("File Unavailable", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    state.dismissError()
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.errorMessage ?? "")
        }
        .alert("Delete File?", isPresented: $state.isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                state.deleteFile {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the file from Vault.")
        }
        .fullScreenCover(item: $state.previewDocument) { previewDocument in
            QuickLookPreview(
                item: previewDocument.item,
                url: previewDocument.url,
                playbackPosition: appState.playbackPosition(for: previewDocument.item.id),
                onPlaybackPositionChange: { seconds in
                    appState.rememberPlaybackPosition(itemID: previewDocument.item.id, seconds: seconds)
                }
            ) {
                state.previewDocument = nil
            }
        }
        .sheet(item: $state.shareDocument) { document in
            FileDetailActivityView(activityItems: [document.url])
        }
        .task(id: state.item.collectionId) {
            state.loadCollectionName()
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

private struct FileDetailSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}
