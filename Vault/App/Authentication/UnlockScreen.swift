import SwiftUI
import VaultSecurity

struct UnlockScreen: View {
    let message: String?
    let isAuthenticating: Bool
    let authenticationTrigger: Int
    let unlockMethod: AuthenticationService.UnlockMethod
    let onUnlock: () async -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Unlock Vault")
                    .font(.largeTitle.bold())
            }

            Button {
                Task {
                    await onUnlock()
                }
            } label: {
                if isAuthenticating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(unlockMethod == .faceID ? "Unlock with Face ID" : "Unlock")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAuthenticating)

            Spacer()
        }
        .padding(24)
        .task(id: authenticationTrigger) {
            let trigger = authenticationTrigger

            guard trigger > 0, !isAuthenticating, message == nil else {
                return
            }

            await onUnlock()
        }
    }
}

#Preview {
    UnlockScreen(
        message: nil,
        isAuthenticating: false,
        authenticationTrigger: 1,
        unlockMethod: .faceID,
        onUnlock: {}
    )
}
