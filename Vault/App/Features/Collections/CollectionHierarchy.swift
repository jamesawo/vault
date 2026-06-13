import Foundation
import VaultStorage

/// Defines the current maximum collection nesting depth and keeps that rule injectable for future settings support.
struct CollectionHierarchySettings {
    let maximumDepth: Int

    nonisolated init(maximumDepth: Int = 3) {
        self.maximumDepth = max(1, maximumDepth)
    }
}

/// Describes a collection as a move destination together with its depth and full ancestor path.
struct CollectionMoveDestination: Identifiable {
    let id: String
    let collection: Collection
    let depth: Int
    let path: [Collection]

    var displayName: String {
        String(repeating: "  ", count: max(0, depth - 1)) + collection.name
    }

    var fullPath: String {
        path.map(\.name).joined(separator: " > ")
    }
}

/// Captures the hierarchy-aware content needed to render a collection detail screen.
struct CollectionDetailContent {
    let collection: Collection
    let path: [Collection]
    let childCollections: [CollectionSummary]
    let items: [VaultItem]
}
