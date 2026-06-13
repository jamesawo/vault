import SwiftUI
import VaultStorage

/// Defines the app-level navigation destinations used by the root navigation stack.
enum AppRoute: Hashable {
    case collections
    case settings
    case collection(Collection)
    case file(VaultItem)
}
