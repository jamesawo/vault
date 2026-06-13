import Foundation
import Observation

/// Owns unlock screen state and coordinates device authentication requests for the authentication feature.
@MainActor
@Observable
final class UnlockState {
    var message: String?
    var isAuthenticating = false
    var authenticationTrigger = 0
    var unlockMethod: AuthenticationService.UnlockMethod

    var onUnlock: (() -> Void)?

    @ObservationIgnored
    private let authenticationService: AuthenticationService

    @ObservationIgnored
    private var authenticationAttempt = 0

    init(authenticationService: AuthenticationService = AuthenticationService()) {
        self.authenticationService = authenticationService
        unlockMethod = authenticationService.preferredUnlockMethod()
    }

    func authenticate() async {
        guard !isAuthenticating else {
            return
        }

        authenticationAttempt += 1
        let currentAttempt = authenticationAttempt

        message = nil
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

            onUnlock?()
        } catch let authenticationError as AuthenticationService.AuthenticationError {
            guard currentAttempt == authenticationAttempt else {
                return
            }

            switch authenticationError {
            case .cancelled:
                message = nil
            case .failed, .unavailable:
                message = authenticationError.errorDescription
            }
        } catch {
            guard currentAttempt == authenticationAttempt else {
                return
            }

            message = error.localizedDescription
        }
    }

    func reset() {
        authenticationAttempt += 1
        isAuthenticating = false
        message = nil
    }

    func requestAutomaticAuthentication() {
        guard !isAuthenticating else {
            return
        }

        authenticationTrigger += 1
    }
}
