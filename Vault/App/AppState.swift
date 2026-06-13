import Observation
import SwiftUI
import VaultSecurity

struct CollectionPreviewState: Equatable {
    var collectionID: String
    var itemID: String
}

/// Coordinates root app state such as lock status, authentication, and app-level navigation.
@MainActor
@Observable
final class AppState {
    var navigationPath = NavigationPath()
    var collectionPreview: CollectionPreviewState?
    var isUnlocked = false
    var authenticationMessage: String?
    var isAuthenticating = false
    var authenticationTrigger = 0
    var unlockMethod: AuthenticationService.UnlockMethod = .standard

    @ObservationIgnored
    private var playbackPositions: [String: Double] = [:]

    private let authenticationService = AuthenticationService()
    private var authenticationAttempt = 0

    init() {
        unlockMethod = authenticationService.preferredUnlockMethod()
    }

    func authenticate() async {
        guard !isAuthenticating, !isUnlocked else {
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

            isUnlocked = true
        } catch let authenticationError as AuthenticationService.AuthenticationError {
            guard currentAttempt == authenticationAttempt else {
                return
            }

            isUnlocked = false
            switch authenticationError {
            case .cancelled:
                authenticationMessage = nil
            case .failed, .unavailable:
                authenticationMessage = authenticationError.errorDescription
            }
        } catch {
            guard currentAttempt == authenticationAttempt else {
                return
            }

            isUnlocked = false
            authenticationMessage = error.localizedDescription
        }
    }

    func lock() {
        authenticationAttempt += 1

        isUnlocked = false
        isAuthenticating = false
        authenticationMessage = nil
    }

    func sceneDidBecomeActive() {
        guard !isUnlocked, !isAuthenticating else {
            return
        }

        authenticationTrigger += 1
    }

    func presentCollectionPreview(collectionID: String, itemID: String) {
        collectionPreview = CollectionPreviewState(collectionID: collectionID, itemID: itemID)
    }

    func updateCollectionPreviewItem(itemID: String) {
        guard collectionPreview != nil else {
            return
        }

        collectionPreview?.itemID = itemID
    }

    func dismissCollectionPreview() {
        collectionPreview = nil
    }

    func playbackPosition(for itemID: String) -> Double {
        playbackPositions[itemID] ?? 0
    }

    func rememberPlaybackPosition(itemID: String, seconds: Double) {
        let normalizedSeconds = max(0, seconds)
        let previousSeconds = playbackPositions[itemID] ?? 0

        guard abs(previousSeconds - normalizedSeconds) >= 1 || normalizedSeconds == 0 else {
            return
        }

        playbackPositions[itemID] = normalizedSeconds
    }
}
