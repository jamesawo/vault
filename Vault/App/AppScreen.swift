import SwiftUI

struct AppScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        if appState.vaultSession.isUnlocked {
            NavigationStack(path: $appState.navigationPath) {
                HomeScreen()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .collections:
                            CollectionsScreen()
                        case .search:
                            SearchScreen()
                        case .settings:
                            SettingsScreen()
                        }
                    }
            }
        } else {
            UnlockScreen(
                message: appState.authenticationMessage,
                isAuthenticating: appState.isAuthenticating,
                shouldAutoAuthenticate: scenePhase == .active,
                onUnlock: { await appState.authenticate() }
            )
        }
    }
}

#Preview {
    let appState = AppState()
    appState.vaultSession.isUnlocked = true

    AppScreen()
        .environment(appState)
}
