//
//  VaultApp.swift
//  Vault
//
//  Created by James Aworo on 10.06.26.
//

import SwiftUI

@main
struct VaultApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppScreen()
                .environment(appState)
                .onChange(of: scenePhase, initial: true) { _, newPhase in
                    switch newPhase {
                    case .active:
                        break
                    case .inactive, .background:
                        appState.lock()
                    @unknown default:
                        appState.lock()
                    }
                }
        }
    }
}
