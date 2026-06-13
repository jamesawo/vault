import SwiftUI
import VaultStorage

struct HomeScreen: View {
    @State private var state = HomeState()
    @State private var selectedImportCollectionID: String?
    @State private var isShowingImportCollectionPicker = false
    @State private var isShowingCreateCollectionPrompt = false
    @State private var newCollectionName = ""

    private var isShowingImportError: Binding<Bool> {
        Binding(
            get: { state.importErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    state.importErrorMessage = nil
                }
            }
        )
    }

    private var isShowingContentError: Binding<Bool> {
        Binding(
            get: { state.contentErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    state.contentErrorMessage = nil
                }
            }
        )
    }

    private var isShowingImportSuccess: Binding<Bool> {
        Binding(
            get: { state.successMessage != nil },
            set: { isPresented in
                if !isPresented {
                    state.successMessage = nil
                }
            }
        )
    }

    var body: some View {
        let baseView = AnyView(
            List {
            Section {
                Button {
                    startImportFlow()
                } label: {
                    Label("Import File", systemImage: "square.and.arrow.down")
                }
            } header: {
                SectionHeader(title: "Import")
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
            handleImportResult(result)
        }
        .confirmationDialog("Choose Collection", isPresented: $isShowingImportCollectionPicker, titleVisibility: .visible) {
            ForEach(state.collectionSummaries) { collection in
                Button(collection.name) {
                    selectedImportCollectionID = collection.id
                    state.isImportPickerPresented = true
                }
            }

            Button("Cancel", role: .cancel) {
                selectedImportCollectionID = nil
            }
        }
        .alert("Create Collection", isPresented: $isShowingCreateCollectionPrompt) {
            TextField("Collection Name", text: $newCollectionName)
            Button("Create") {
                createCollectionAndContinueImport()
            }
            Button("Cancel", role: .cancel) {
                newCollectionName = ""
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

    private func startImportFlow() {
        if state.collectionSummaries.isEmpty {
            newCollectionName = ""
            isShowingCreateCollectionPrompt = true
            return
        }

        isShowingImportCollectionPicker = true
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let selectedImportCollectionID else {
                state.importErrorMessage = "Choose a collection before importing."
                return
            }

            guard !urls.isEmpty else {
                state.importErrorMessage = "Choose at least one file to import."
                return
            }

            Task {
                await state.importFiles(from: urls, collectionID: selectedImportCollectionID)
                self.selectedImportCollectionID = nil
            }
        case let .failure(error):
            state.importErrorMessage = error.localizedDescription
            selectedImportCollectionID = nil
        }
    }

    private var collectionsSection: some View {
        Section {
            ForEach(state.filteredCollectionSummaries) { collection in
                collectionRow(collection)
            }
        } header: {
            HStack {
                SectionHeader(title: "Collections")
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
            HStack {
                Text(summary.name)
                Spacer()
                Text("\(summary.itemCount)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func createCollectionAndContinueImport() {
        do {
            let collection = try state.createCollection(named: newCollectionName)
            newCollectionName = ""
            selectedImportCollectionID = collection.id
            Task { @MainActor in
                state.isImportPickerPresented = true
            }
        } catch {
            state.contentErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        HomeScreen()
    }
}
