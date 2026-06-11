import Observation
import SwiftUI
import VaultSecurity

@MainActor
@Observable
final class AppState {
    var navigationPath = NavigationPath()
    var authenticationMessage: String?
    var isAuthenticating = false
    let vaultSession = VaultSessionState()

    private let authenticationService = AuthenticationService()
    private var authenticationAttempt = 0

    func authenticate() async {
        guard !isAuthenticating, !vaultSession.isUnlocked else {
            return
        }

        authenticationAttempt += 1
        let currentAttempt = authenticationAttempt

        authenticationMessage = nil
        isAuthenticating = true

        defer {
            if currentAttempt == authenticationAttempt {
                isAuthenticating = false
            }
        }

        do {
            try await authenticationService.authenticate()

            guard currentAttempt == authenticationAttempt else {
                return
            }

            vaultSession.isUnlocked = true
        } catch let authenticationError as AuthenticationService.AuthenticationError {
            guard currentAttempt == authenticationAttempt else {
                return
            }

            vaultSession.isUnlocked = false
            authenticationMessage = authenticationError.errorDescription
        } catch {
            guard currentAttempt == authenticationAttempt else {
                return
            }

            vaultSession.isUnlocked = false
            authenticationMessage = error.localizedDescription
        }
    }

    func lock() {
        authenticationAttempt += 1

        if vaultSession.isUnlocked {
            navigationPath = NavigationPath()
        }

        vaultSession.isUnlocked = false
        isAuthenticating = false
        authenticationMessage = nil
    }
}
