import SwiftUI
import VaultStorage

/// Renders the root app flow and switches between the locked and unlocked experiences.
struct AppScreen: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        if appState.isUnlocked {
            NavigationStack(path: $appState.navigationPath) {
                HomeScreen()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .collections:
                            CollectionsScreen()
                        case .settings:
                            SettingsScreen()
                        case let .collection(collection):
                            CollectionDetailScreen(collection: collection)
                        case let .file(item):
                            FileDetailScreen(item: item)
                        }
                    }
            }
        } else {
            UnlockScreen(
                message: appState.authenticationMessage,
                isAuthenticating: appState.isAuthenticating,
                authenticationTrigger: appState.authenticationTrigger,
                unlockMethod: appState.unlockMethod,
                onUnlock: { await appState.authenticate() }
            )
        }
    }
}

#Preview {
    AppScreenPreview()
}

private struct AppScreenPreview: View {
    @State private var appState = AppState()

    var body: some View {
        AppScreen()
            .environment(appState)
            .task {
                appState.isUnlocked = true
            }
    }
}
