import SwiftUI
import VaultStorage

/// Renders the collections list and forwards collection actions to `CollectionsState`.
struct CollectionsScreen: View {
    @State private var state = CollectionsState()

    var body: some View {
        @Bindable var state = state

        List(state.filteredCollections) { collection in
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
                        state.beginCreateCollection()
                    }

                    Button("Select Collections") {
                        state.showPlaceholder("Multi-select collection management will be added later.")
                    }

                    Button("Manage Collections") {
                        state.showPlaceholder("Advanced collection management will be added later.")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if state.filteredCollections.isEmpty, state.errorMessage == nil {
                ContentUnavailableView(
                    state.searchText.isEmpty ? "No Collections" : "No Results",
                    systemImage: "folder",
                    description: Text(
                        state.searchText.isEmpty
                            ? "Create a collection to start organizing files in Vault."
                            : "Try a different search term."
                    )
                )
            }
        }
        .alert("Collections Unavailable", isPresented: Binding(
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
        .alert("Not Available Yet", isPresented: Binding(
            get: { state.placeholderMessage != nil },
            set: { isPresented in
                if !isPresented {
                    state.dismissPlaceholder()
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.placeholderMessage ?? "")
        }
        .alert("Create Collection", isPresented: $state.isShowingCreateCollectionPrompt) {
            TextField("Collection Name", text: $state.newCollectionName)
            Button("Create") {
                state.createCollection()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new collection.")
        }
        .searchable(text: $state.searchText)
        .onAppear {
            state.loadCollections()
        }
        .task {
            state.loadCollections()
        }
    }
}

#Preview {
    NavigationStack {
        CollectionsScreen()
    }
}
