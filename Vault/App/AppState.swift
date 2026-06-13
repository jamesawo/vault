import Observation
import SwiftUI

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
    let unlockState: UnlockState

    @ObservationIgnored
    private var playbackPositions: [String: Double] = [:]

    init() {
        let unlockState = UnlockState()
        self.unlockState = unlockState
        unlockState.onUnlock = { [weak self] in
            self?.isUnlocked = true
        }
    }

    func lock() {
        isUnlocked = false
        unlockState.reset()
    }

    func sceneDidBecomeActive() {
        guard !isUnlocked else {
            return
        }

        unlockState.requestAutomaticAuthentication()
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
