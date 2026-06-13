import SwiftUI
import UniformTypeIdentifiers
import VaultStorage

struct CollectionDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var currentCollection: Collection
    @State private var items: [VaultItem] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var isShowingCollectionInfo = false
    @State private var isShowingRenamePrompt = false
    @State private var renamedCollectionName = ""
    @State private var isShowingDeleteConfirmation = false
    @State private var fileInteractions = VaultFileInteractionState()
    @State private var itemPendingDeletion: VaultItem?
    @State private var isShowingImportPicker = false

    init(collection: Collection) {
        _currentCollection = State(initialValue: collection)
    }

    private var filteredItems: [VaultItem] {
        guard !searchText.isEmpty else {
            return items
        }

        return items.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private var isShowingCollectionError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private var isShowingDeleteFileConfirmation: Binding<Bool> {
        Binding(
            get: { itemPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    itemPendingDeletion = nil
                }
            }
        )
    }

    private var isShowingFileError: Binding<Bool> {
        Binding(
            get: { fileInteractions.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    fileInteractions.errorMessage = nil
                }
            }
        )
    }

    private var currentPreviewIndex: Int? {
        guard let preview = appState.collectionPreview,
              preview.collectionID == currentCollection.id else {
            return nil
        }

        return items.firstIndex { $0.id == preview.itemID }
    }

    private var isShowingPreview: Binding<Bool> {
        Binding(
            get: {
                currentPreviewIndex != nil
            },
            set: { isPresented in
                if !isPresented {
                    appState.dismissCollectionPreview()
                }
            }
        )
    }

    var body: some View {
        let displayedItems = filteredItems

        let baseView = AnyView(
            List {
                filesSection(displayedItems)
            }
            .navigationTitle(currentCollection.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Import File") {
                            isShowingImportPicker = true
                        }

                        Button("Rename Collection") {
                            renamedCollectionName = currentCollection.name
                            isShowingRenamePrompt = true
                        }

                        Button("Collection Info") {
                            isShowingCollectionInfo = true
                        }

                        Button("Delete Collection", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay {
                if fileInteractions.isPreparingFile {
                    ProgressView("Working…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if displayedItems.isEmpty, errorMessage == nil {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Files" : "No Results",
                        systemImage: "doc",
                        description: Text(
                            searchText.isEmpty
                                ? "Files imported into \(currentCollection.name) will appear here."
                                : "Try a different search term."
                        )
                    )
                }
            }
        )

        let importConfiguredView = AnyView(
            baseView.fileImporter(isPresented: $isShowingImportPicker, allowedContentTypes: [.item]) { result in
                switch result {
                case let .success(url):
                    importFile(from: url)
                case let .failure(error):
                    errorMessage = error.localizedDescription
                }
            }
        )

        let errorAlertView = AnyView(
            importConfiguredView.alert("Collection Unavailable", isPresented: isShowingCollectionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        )

        let renameAlertView = AnyView(
            errorAlertView.alert("Rename Collection", isPresented: $isShowingRenamePrompt) {
                TextField("Collection Name", text: $renamedCollectionName)
                Button("Save") {
                    renameCollection()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a new name for this collection.")
            }
        )

        let deleteCollectionAlertView = AnyView(
            renameAlertView.alert("Delete Collection?", isPresented: $isShowingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteCollection()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deleting a collection will permanently remove all files stored inside it. This action cannot be undone.")
            }
        )

        let deleteFileAlertView = AnyView(
            deleteCollectionAlertView.alert("Delete File?", isPresented: isShowingDeleteFileConfirmation, presenting: itemPendingDeletion) { item in
                Button("Delete", role: .destructive) {
                    delete(item)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This will permanently remove the file from Vault.")
            }
        )

        let infoSheetView = AnyView(
            deleteFileAlertView.sheet(isPresented: $isShowingCollectionInfo) {
                collectionInfoSheet
            }
        )

        let previewView = AnyView(
            infoSheetView.fullScreenCover(isPresented: isShowingPreview) {
                if let previewStartIndex = currentPreviewIndex {
                    CollectionFilePreviewScreen(
                        items: items,
                        startIndex: previewStartIndex,
                        onDismiss: {
                            appState.dismissCollectionPreview()
                        },
                        onCurrentItemChange: { item in
                            appState.updateCollectionPreviewItem(itemID: item.id)
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "File Unavailable",
                        systemImage: "doc",
                        description: Text("This file can no longer be opened.")
                    )
                }
            }
        )

        let sharingView = AnyView(
            previewView.sheet(item: $fileInteractions.shareDocument) { document in
                ActivityView(activityItems: [document.url])
            }
        )

        return AnyView(
            sharingView.alert("File Unavailable", isPresented: isShowingFileError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(fileInteractions.errorMessage ?? "")
            }
            .searchable(text: $searchText)
            .onAppear {
                loadItems()
            }
            .task(id: currentCollection.id) {
                loadItems()
            }
            .onChange(of: items) { _, updatedItems in
                guard let preview = appState.collectionPreview,
                      preview.collectionID == currentCollection.id,
                      !updatedItems.contains(where: { $0.id == preview.itemID }) else {
                    return
                }

                appState.dismissCollectionPreview()
            }
        )
    }

    @ViewBuilder
    private func filesSection(_ displayedItems: [VaultItem]) -> some View {
        Section {
            ForEach(displayedItems, id: \.id) { item in
                fileRow(item)
            }
        } header: {
            SectionHeader(title: "Files")
        }
    }

    private var collectionInfoSheet: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Collection", value: currentCollection.name)
                    LabeledContent("Files", value: "\(items.count)")
                    LabeledContent("Created", value: currentCollection.createdAt.formatted(date: .abbreviated, time: .omitted))
                }

                Section {
                    Text("Deleting a collection removes the collection and every file inside it after confirmation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Collection Info")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingCollectionInfo = false
                    }
                }
            }
        }
    }

    private func loadItems() {
        do {
            let storageService = try VaultStorageService(
                appGroupIdentifier: VaultSharedConfiguration.appGroupIdentifier
            )
            if let refreshedCollection = try storageService.collection(id: currentCollection.id) {
                currentCollection = refreshedCollection
            }

            items = try storageService.listItems()
                .filter { $0.collectionId == currentCollection.id }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importFile(from url: URL) {
        do {
            let importService = try VaultImportService()
            _ = try importService.importFile(from: url, collectionID: currentCollection.id)
            loadItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openPreview(for item: VaultItem) {
        appState.presentCollectionPreview(collectionID: currentCollection.id, itemID: item.id)
    }

    @ViewBuilder
    private func fileRow(_ item: VaultItem) -> some View {
        CollectionFileRowView(
            item: item,
            onOpen: { openPreview(for: item) },
            onInfo: { appState.navigationPath.append(AppRoute.file(item)) },
            onShare: { fileInteractions.share(item) },
            onDelete: { itemPendingDeletion = item }
        )
    }

    private func renameCollection() {
        do {
            let storageService = try VaultStorageService(
                appGroupIdentifier: VaultSharedConfiguration.appGroupIdentifier
            )
            currentCollection = try storageService.renameCollection(id: currentCollection.id, newName: renamedCollectionName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCollection() {
        do {
            let storageService = try VaultStorageService(
                appGroupIdentifier: VaultSharedConfiguration.appGroupIdentifier
            )
            try storageService.deleteCollection(id: currentCollection.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ item: VaultItem) {
        do {
            let fileAccessService = try VaultFileAccessService()
            try fileAccessService.delete(item: item)
            itemPendingDeletion = nil
            loadItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CollectionFileRowView: View {
    let item: VaultItem
    let onOpen: () -> Void
    let onInfo: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VaultFileThumbnailView(item: item, size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .lineLimit(1)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open", action: onOpen)
            Button("Preview Info", action: onInfo)
            Button("Share", action: onShare)

            Button("Move") {}
                .disabled(true)

            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

#Preview {
    NavigationStack {
        CollectionDetailScreen(
            collection: Collection(
                id: VaultStorageService.starterCollectionID,
                name: "Documents",
                createdAt: .now
            )
        )
    }
}
