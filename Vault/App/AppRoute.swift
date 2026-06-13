import SwiftUI
import VaultStorage

enum AppRoute: Hashable {
    case collections
    case settings
    case collection(Collection)
    case file(VaultItem)
}
