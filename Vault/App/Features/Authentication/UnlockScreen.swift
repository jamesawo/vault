import SwiftUI

/// Renders the unlock experience and forwards user actions to `UnlockState`.
struct UnlockScreen: View {
    @Bindable var state: UnlockState

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
                    await state.authenticate()
                }
            } label: {
                if state.isAuthenticating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(state.unlockMethod == .faceID ? "Unlock with Face ID" : "Unlock")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(state.isAuthenticating)

            Spacer()
        }
        .padding(24)
        .task(id: state.authenticationTrigger) {
            let trigger = state.authenticationTrigger

            guard trigger > 0, !state.isAuthenticating, state.message == nil else {
                return
            }

            await state.authenticate()
        }
    }
}

#Preview {
    UnlockScreen(state: UnlockState())
}
