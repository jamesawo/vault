import SwiftUI
import VaultStorage

struct CollectionsScreen: View {
    @State private var collections: [CollectionSummary] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var placeholderMessage: String?
    @State private var isShowingCreateCollectionPrompt = false
    @State private var newCollectionName = ""

    private var filteredCollections: [CollectionSummary] {
        guard !searchText.isEmpty else {
            return collections
        }

        return collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(filteredCollections) { collection in
            NavigationLink(value: AppRoute.collection(collection.collection)) {
                HStack {
                    Label(collection.name, systemImage: "folder")
                    Spacer()
                    Text("\(collection.itemCount)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Collections")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Create Collection") {
                        newCollectionName = ""
                        isShowingCreateCollectionPrompt = true
                    }

                    Button("Select Collections") {
                        placeholderMessage = "Multi-select collection management will be added later."
                    }

                    Button("Manage Collections") {
                        placeholderMessage = "Advanced collection management will be added later."
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if filteredCollections.isEmpty, errorMessage == nil {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Collections" : "No Results",
                    systemImage: "folder",
                    description: Text(
                        searchText.isEmpty
                            ? "Create a collection to start organizing files in Vault."
                            : "Try a different search term."
                    )
                )
            }
        }
        .alert("Collections Unavailable", isPresented: Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Not Available Yet", isPresented: Binding(
            get: { placeholderMessage != nil },
            set: { isPresented in
                if !isPresented {
                    placeholderMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(placeholderMessage ?? "")
        }
        .alert("Create Collection", isPresented: $isShowingCreateCollectionPrompt) {
            TextField("Collection Name", text: $newCollectionName)
            Button("Create") {
                createCollection()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new collection.")
        }
        .searchable(text: $searchText)
        .onAppear {
            loadCollections()
        }
        .task {
            loadCollections()
        }
    }

    private func loadCollections() {
        do {
            let storageService = try VaultStorageService(
                appGroupIdentifier: VaultSharedConfiguration.appGroupIdentifier
            )
            let items = try storageService.listItems()

            collections = try storageService.listCollections()
                .map { collection in
                    CollectionSummary(
                        id: collection.id,
                        collection: collection,
                        itemCount: items.filter { $0.collectionId == collection.id }.count
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.name != rhs.name {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }

                    return lhs.collection.createdAt < rhs.collection.createdAt
                }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createCollection() {
        do {
            let storageService = try VaultStorageService(
                appGroupIdentifier: VaultSharedConfiguration.appGroupIdentifier
            )
            _ = try storageService.createCollection(
                id: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
                name: newCollectionName
            )
            loadCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        CollectionsScreen()
    }
}
