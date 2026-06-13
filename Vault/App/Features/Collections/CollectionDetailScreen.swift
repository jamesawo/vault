import SwiftUI
import UniformTypeIdentifiers
import VaultStorage

/// Renders collection detail UI and forwards collection hierarchy and file actions to `CollectionDetailState`.
struct CollectionDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var state: CollectionDetailState

    init(collection: Collection) {
        _state = State(initialValue: CollectionDetailState(collection: collection))
    }

    private var isShowingCollectionError: Binding<Bool> {
        Binding(
            get: { state.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    state.dismissError()
                }
            }
        )
    }

    private var isShowingDeleteFileConfirmation: Binding<Bool> {
        Binding(
            get: { state.itemPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    state.dismissPendingDeletion()
                }
            }
        )
    }

    private var isShowingFileError: Binding<Bool> {
        Binding(
            get: { state.fileInteractions.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    state.dismissFileError()
                }
            }
        )
    }

    private var isShowingPreview: Binding<Bool> {
        Binding(
            get: {
                state.currentPreviewIndex(preview: appState.collectionPreview) != nil
            },
            set: { isPresented in
                if !isPresented {
                    appState.dismissCollectionPreview()
                }
            }
        )
    }

    private var isShowingMovePicker: Binding<Bool> {
        Binding(
            get: { state.isShowingMoveDestinationPicker },
            set: { isPresented in
                if !isPresented {
                    state.dismissMovePicker()
                }
            }
        )
    }

    var body: some View {
        @Bindable var state = state

        let displayedChildCollections = state.filteredChildCollections
        let displayedItems = state.filteredItems

        let baseView = AnyView(
            List {
                breadcrumbSection

                if !displayedChildCollections.isEmpty {
                    childCollectionsSection(displayedChildCollections)
                }

                if !displayedItems.isEmpty {
                    filesSection(displayedItems)
                }
            }
            .navigationTitle(state.currentCollection.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add Sub-collection") {
                            state.beginCreateSubcollection()
                        }
                        .disabled(!state.canCreateSubcollection)

                        Button("Import File") {
                            state.isShowingImportPicker = true
                        }

                        Button("Rename Collection") {
                            state.beginRenameCollection()
                        }

                        Button("Collection Info") {
                            state.isShowingCollectionInfo = true
                        }

                        Button("Delete Collection", role: .destructive) {
                            state.isShowingDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay {
                if state.fileInteractions.isPreparingFile {
                    ProgressView("Working…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if displayedChildCollections.isEmpty, displayedItems.isEmpty, state.errorMessage == nil {
                    ContentUnavailableView(
                        state.searchText.isEmpty ? "Empty Collection" : "No Results",
                        systemImage: "folder",
                        description: Text(
                            state.searchText.isEmpty
                                ? "Sub-collections and imported files will appear here."
                                : "Try a different search term."
                        )
                    )
                }
            }
        )

        let importConfiguredView = AnyView(
            baseView.fileImporter(isPresented: $state.isShowingImportPicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                state.handleImportResult(result)
            }
        )

        let errorAlertView = AnyView(
            importConfiguredView.alert("Collection Unavailable", isPresented: isShowingCollectionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(state.errorMessage ?? "")
            }
        )

        let renameAlertView = AnyView(
            errorAlertView.alert("Rename Collection", isPresented: $state.isShowingRenamePrompt) {
                TextField("Collection Name", text: $state.renamedCollectionName)
                Button("Save") {
                    state.renameCollection()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a new name for this collection.")
            }
        )

        let createSubcollectionAlertView = AnyView(
            renameAlertView.alert("Add Sub-collection", isPresented: $state.isShowingCreateSubcollectionPrompt) {
                TextField("Sub-collection Name", text: $state.newSubcollectionName)
                Button("Create") {
                    state.createSubcollection()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Collections can be nested up to \(state.maximumHierarchyDepth) levels.")
            }
        )

        let deleteCollectionAlertView = AnyView(
            createSubcollectionAlertView.alert("Delete Collection?", isPresented: $state.isShowingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    state.deleteCollection {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only empty collections can be deleted. Remove any sub-collections and files first.")
            }
        )

        let deleteFileAlertView = AnyView(
            deleteCollectionAlertView.alert("Delete File?", isPresented: isShowingDeleteFileConfirmation, presenting: state.itemPendingDeletion) { _ in
                Button("Delete", role: .destructive) {
                    state.deletePendingItem()
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This will permanently remove the file from Vault.")
            }
        )

        let infoSheetView = AnyView(
            deleteFileAlertView.sheet(isPresented: $state.isShowingCollectionInfo) {
                collectionInfoSheet
            }
        )

        let previewView = AnyView(
            infoSheetView.fullScreenCover(isPresented: isShowingPreview) {
                if let previewStartIndex = state.currentPreviewIndex(preview: appState.collectionPreview) {
                    CollectionFilePreviewScreen(
                        items: state.items,
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
            previewView.sheet(item: $state.fileInteractions.shareDocument) { document in
                CollectionsActivityView(activityItems: [document.url])
            }
        )

        let movePickerView = AnyView(
            sharingView.sheet(isPresented: isShowingMovePicker) {
                CollectionMoveDestinationPicker(
                    itemName: state.itemPendingMove?.displayName ?? "File",
                    destinations: state.moveDestinations,
                    onSelect: { destination in
                        state.movePendingItem(to: destination)
                    },
                    onDismiss: {
                        state.dismissMovePicker()
                    }
                )
            }
        )

        return AnyView(
            movePickerView.alert("File Unavailable", isPresented: isShowingFileError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(state.fileInteractions.errorMessage ?? "")
            }
            .searchable(text: $state.searchText)
            .onAppear {
                state.loadItems()
            }
            .task(id: state.currentCollection.id) {
                state.loadItems()
            }
            .onChange(of: state.items) { _, _ in
                state.updatePreviewAvailability(in: appState)
            }
        )
    }

    private var breadcrumbSection: some View {
        Section {
            Text(state.breadcrumbText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func childCollectionsSection(_ collections: [CollectionSummary]) -> some View {
        Section {
            ForEach(collections) { collection in
                NavigationLink(value: AppRoute.collection(collection.collection)) {
                    HStack {
                        Label(collection.name, systemImage: "folder")
                        Spacer()
                        if collection.itemCount > 0 {
                            Text("\(collection.itemCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            CollectionsSectionHeader(title: "Collections")
        }
    }

    @ViewBuilder
    private func filesSection(_ displayedItems: [VaultItem]) -> some View {
        Section {
            ForEach(displayedItems, id: \.id) { item in
                fileRow(item)
            }
        } header: {
            CollectionsSectionHeader(title: "Files")
        }
    }

    private var collectionInfoSheet: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Collection", value: state.currentCollection.name)
                    LabeledContent("Path", value: state.breadcrumbText)
                    LabeledContent("Sub-collections", value: "\(state.childCollections.count)")
                    LabeledContent("Files", value: "\(state.items.count)")
                    LabeledContent("Created", value: state.currentCollection.createdAt.formatted(date: .abbreviated, time: .omitted))
                }

                Section {
                    Text("Collections can contain sub-collections and files. Only empty collections can be deleted.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Collection Info")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        state.dismissCollectionInfo()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fileRow(_ item: VaultItem) -> some View {
        CollectionFileRowView(
            item: item,
            onOpen: { state.openPreview(in: appState, item: item) },
            onInfo: { appState.navigationPath.append(AppRoute.file(item)) },
            onShare: { state.fileInteractions.share(item) },
            onMove: { state.beginMove(item) },
            onDelete: { state.confirmDelete(item) }
        )
    }
}

private struct CollectionsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}

private struct CollectionFileRowView: View {
    let item: VaultItem
    let onOpen: () -> Void
    let onInfo: () -> Void
    let onShare: () -> Void
    let onMove: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                CollectionFileThumbnailView(item: item, size: 52)

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
            Button("Move", action: onMove)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

private struct CollectionMoveDestinationPicker: View {
    let itemName: String
    let destinations: [CollectionMoveDestination]
    let onSelect: (CollectionMoveDestination) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List(destinations) { destination in
                Button {
                    onSelect(destination)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(destination.displayName)
                            .foregroundStyle(.primary)
                        Text(destination.fullPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Move \(itemName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
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
