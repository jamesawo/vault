import SwiftUI
import VaultStorage

struct CollectionFilePreviewScreen: View {
    @Environment(AppState.self) private var appState

    let items: [VaultItem]
    let startIndex: Int
    let onDismiss: () -> Void
    let onCurrentItemChange: (VaultItem) -> Void

    @State private var currentIndex: Int
    @State private var currentDocument: PresentedDocument?
    @State private var shareDocument: PresentedDocument?
    @State private var errorMessage: String?
    @State private var isPreparingFile = false
    @State private var isShowingFullView = false

    init(
        items: [VaultItem],
        startIndex: Int,
        onDismiss: @escaping () -> Void,
        onCurrentItemChange: @escaping (VaultItem) -> Void
    ) {
        self.items = items
        self.startIndex = startIndex
        self.onDismiss = onDismiss
        self.onCurrentItemChange = onCurrentItemChange
        _currentIndex = State(initialValue: startIndex)
    }

    private var currentItem: VaultItem? {
        guard items.indices.contains(currentIndex) else {
            return nil
        }

        return items[currentIndex]
    }

    var body: some View {
        NavigationStack {
            Group {
                if let currentDocument {
                    VaultItemPreviewContent(
                        item: currentDocument.item,
                        url: currentDocument.url,
                        playbackPosition: appState.playbackPosition(for: currentDocument.item.id),
                        onPlaybackPositionChange: { seconds in
                            appState.rememberPlaybackPosition(itemID: currentDocument.item.id, seconds: seconds)
                        }
                    )
                } else if let currentItem {
                    ProgressView("Opening \(currentItem.displayName)…")
                } else {
                    ContentUnavailableView(
                        "File Unavailable",
                        systemImage: "doc",
                        description: Text("This file can no longer be opened.")
                    )
                }
            }
            .navigationTitle(currentItem?.displayName ?? "File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            isShowingFullView.toggle()
                        } label: {
                            Image(systemName: isShowingFullView ? "rectangle.inset.filled" : "rectangle.expand.vertical")
                        }
                        .disabled(currentDocument == nil)

                        Button {
                            shareCurrentFile()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(currentDocument == nil || isPreparingFile)
                    }
                }
            }
            .overlay {
                if isPreparingFile {
                    ProgressView("Preparing…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isShowingFullView {
                    controlsBar
                }
            }
        }
        .task(id: currentItem?.id) {
            await loadCurrentDocument()
        }
        .sheet(item: $shareDocument) { document in
            ActivityView(activityItems: [document.url])
        }
        .alert("File Unavailable", isPresented: Binding(
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
    }

    private var controlsBar: some View {
        HStack(spacing: 12) {
            Button {
                currentIndex -= 1
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(currentIndex <= 0 || isPreparingFile)

            Button {
                currentIndex += 1
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.borderedProminent)
            .disabled(currentIndex >= items.count - 1 || isPreparingFile)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }

    private func shareCurrentFile() {
        guard let currentDocument else {
            return
        }

        shareDocument = currentDocument
    }

    private func loadCurrentDocument() async {
        guard let currentItem else {
            currentDocument = nil
            return
        }

        onCurrentItemChange(currentItem)

        isPreparingFile = true
        defer { isPreparingFile = false }

        do {
            let fileDetailService = try FileDetailService()
            currentDocument = try fileDetailService.preparedDocument(for: currentItem)
            errorMessage = nil
        } catch {
            currentDocument = nil
            errorMessage = error.localizedDescription
        }
    }
}
