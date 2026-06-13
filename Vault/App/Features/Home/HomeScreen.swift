import SwiftUI
import VaultStorage

/// Renders the home dashboard and forwards search and import actions to `HomeState`.
struct HomeScreen: View {
    @ScaledMetric(relativeTo: .title3) private var collectionIconSize = 16
    @ScaledMetric(relativeTo: .caption) private var countIconSize = 10

    @State private var state = HomeState()

    private var isShowingImportError: Binding<Bool> {
        Binding(
            get: { state.importErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    state.dismissImportError()
                }
            }
        )
    }

    private var isShowingContentError: Binding<Bool> {
        Binding(
            get: { state.contentErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    state.dismissContentError()
                }
            }
        )
    }

    private var isShowingImportSuccess: Binding<Bool> {
        Binding(
            get: { state.successMessage != nil },
            set: { isPresented in
                if !isPresented {
                    state.dismissSuccessMessage()
                }
            }
        )
    }

    var body: some View {
        @Bindable var state = state

        let baseView = AnyView(
            List {
            Section {
                Button {
                    state.startImportFlow()
                } label: {
                    Label("Import File", systemImage: "square.and.arrow.down")
                        .font(.system(size: collectionIconSize, weight: .regular))               }
            } header: {
                HomeSectionHeader(title: "Import")
            }

            if !state.filteredCollectionSummaries.isEmpty {
                collectionsSection
            }
        }
        .navigationTitle("Vault")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.settings) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .overlay {
            if state.isImporting {
                ProgressView("Importing…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else if state.filteredCollectionSummaries.isEmpty, !state.searchText.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
            }
        }
        )

        let importConfiguredView = AnyView(
            baseView.fileImporter(
            isPresented: $state.isImportPickerPresented,
            allowedContentTypes: state.allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            state.handleImportResult(result)
        }
        .confirmationDialog("Choose Collection", isPresented: $state.isShowingImportCollectionPicker, titleVisibility: .visible) {
            ForEach(state.collectionSummaries) { collection in
                Button(collection.name) {
                    state.chooseImportCollection(collection.id)
                }
            }

            Button("Cancel", role: .cancel) {
                state.cancelImportFlow()
            }
        }
        .alert("Create Collection", isPresented: $state.isShowingCreateCollectionPrompt) {
            TextField("Collection Name", text: $state.newCollectionName)
            Button("Create") {
                state.createCollectionAndContinueImport()
            }
            Button("Cancel", role: .cancel) {
                state.newCollectionName = ""
            }
        } message: {
            Text("Create a collection before importing a file into Vault.")
        }
        )

        return AnyView(
            importConfiguredView.alert("Import Failed", isPresented: isShowingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.importErrorMessage ?? "")
        }
        .alert("Vault Unavailable", isPresented: isShowingContentError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.contentErrorMessage ?? "")
        }
        .alert("Import Complete", isPresented: isShowingImportSuccess) {
            Button("OK") {}
        } message: {
            Text(state.successMessage ?? "")
        }
        .searchable(text: $state.searchText)
        .onAppear {
            state.loadContent()
        }
        .task {
            state.loadContent()
        }
        )
    }

    private var collectionsSection: some View {
        Section {
            ForEach(state.filteredCollectionSummaries) { collection in
                collectionRow(collection)
            }
        } header: {
            HStack {
                HomeSectionHeader(title: "Collections")
                Spacer()
                NavigationLink(value: AppRoute.collections) {
                    HStack(spacing: 4) {
                        Text("All")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .padding(.leading, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func collectionRow(_ summary: CollectionSummary) -> some View {
        let collection = summary.collection

        NavigationLink(value: AppRoute.collection(collection)) {
            HStack(spacing: 16) {
                Image(systemName: "folder")
                    .font(.system(size: collectionIconSize, weight: .regular))
                    .foregroundStyle(.blue)
                    .frame(width: collectionIconSize + 8, height: collectionIconSize + 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.name)
                        .foregroundStyle(.primary)

                    HStack(spacing: 16) {
                        countLabel(systemName: "doc", count: summary.itemCount)

                        if summary.childCollectionCount > 0 {
                            countLabel(systemName: "folder", count: summary.childCollectionCount)
                        }
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func countLabel(systemName: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: countIconSize, weight: .medium))
                .foregroundStyle(.secondary)

            Text("\(count)")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    NavigationStack {
        HomeScreen()
    }
}

private struct HomeSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}
