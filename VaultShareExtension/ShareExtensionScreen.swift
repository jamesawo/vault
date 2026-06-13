import SwiftUI
import VaultStorage

struct ShareExtensionScreen: View {
    @StateObject private var state: ShareExtensionState

    init(state: ShareExtensionState) {
        _state = StateObject(wrappedValue: state)
    }

    var body: some View {
        NavigationStack {
            Group {
                if state.isLoading {
                    ProgressView("Loading…")
                } else if let successMessage = state.successMessage {
                    statusView(
                        title: "Imported",
                        systemImage: "checkmark.circle.fill",
                        message: successMessage
                    )
                } else if state.collections.isEmpty {
                    statusView(
                        title: "No Collections",
                        systemImage: "folder.badge.plus",
                        message: "Create a collection to import this file into Vault."
                    )
                } else {
                    List(state.collections) { collection in
                        Button {
                            Task {
                                await state.importIntoCollection(collection.id)
                            }
                        } label: {
                            Text(collection.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(state.isImporting)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .overlay {
                if state.isImporting {
                    ProgressView("Importing…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .navigationTitle("Choose Collection")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        state.cancel()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("New") {
                        state.newCollectionName = ""
                        state.isShowingCreateCollectionPrompt = true
                    }
                    .disabled(state.isImporting)
                }
            }
            .alert("Create Collection", isPresented: $state.isShowingCreateCollectionPrompt) {
                TextField("Collection Name", text: $state.newCollectionName)
                Button("Create") {
                    Task {
                        await state.createCollectionAndContinueImport()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Create a collection before importing the shared file.")
            }
            .alert("Import Failed", isPresented: Binding(
                get: { state.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        state.errorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(state.errorMessage ?? "")
            }
        }
    }

    private func statusView(title: String, systemImage: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
