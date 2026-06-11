import SwiftUI

struct UnlockScreen: View {
    let message: String?
    let isAuthenticating: Bool
    let shouldAutoAuthenticate: Bool
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

                Text("Authenticate with your device credentials to continue.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
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
                    Text("Authenticate")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAuthenticating)

            Spacer()
        }
        .padding(24)
        .task(id: shouldAutoAuthenticate) {
            guard shouldAutoAuthenticate, !isAuthenticating, message == nil else {
                return
            }

            await onUnlock()
        }
    }
}

#Preview {
    UnlockScreen(message: nil, isAuthenticating: false, shouldAutoAuthenticate: true, onUnlock: {})
}
