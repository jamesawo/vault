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
                .task {
                    appState.sceneDidBecomeActive()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        appState.sceneDidBecomeActive()
                    case .inactive:
                        break
                    case .background:
                        appState.lock()
                    @unknown default:
                        appState.lock()
                    }
                }
        }
    }
}
