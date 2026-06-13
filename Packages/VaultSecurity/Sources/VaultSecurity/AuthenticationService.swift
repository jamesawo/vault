import LocalAuthentication

public struct AuthenticationService: Sendable {
    public enum UnlockMethod: Sendable, Equatable {
        case faceID
        case standard
    }

    public enum AuthenticationError: LocalizedError, Equatable {
        case unavailable(reason: String)
        case failed(reason: String)
        case cancelled

        public var errorDescription: String? {
            switch self {
            case let .unavailable(reason):
                return reason
            case let .failed(reason):
                return reason
            case .cancelled:
                return "Authentication was cancelled."
            }
        }
    }

    private let localizedReason: String

    public init(localizedReason: String = "Authenticate to unlock your vault.") {
        self.localizedReason = localizedReason
    }

    public func preferredUnlockMethod() -> UnlockMethod {
        let context = LAContext()
        var evaluationError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &evaluationError) else {
            return .standard
        }

        return context.biometryType == .faceID ? .faceID : .standard
    }

    public func authenticate() async throws {
        let context = LAContext()
        var evaluationError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
            throw mapAvailabilityError(evaluationError)
        }

        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: localizedReason) { success, error in
                if success {
                    continuation.resume()
                    return
                }

                if let error {
                    continuation.resume(throwing: mapEvaluationError(error))
                } else {
                    continuation.resume(throwing: AuthenticationError.failed(reason: "Authentication failed. Try again."))
                }
            }
        }
    }

    private func mapAvailabilityError(_ error: NSError?) -> AuthenticationError {
        guard let error else {
            return .unavailable(reason: "Device authentication is not available on this device.")
        }

        switch laErrorCode(for: error) {
        case .biometryNotAvailable:
            return .unavailable(reason: "Biometric authentication is not available on this device.")
        case .biometryNotEnrolled:
            return .unavailable(reason: "Biometric authentication is not enrolled on this device.")
        case .passcodeNotSet:
            return .unavailable(reason: "A device passcode is required to unlock Vault.")
        default:
            return .unavailable(reason: error.localizedDescription)
        }
    }

    private func mapEvaluationError(_ error: Error) -> AuthenticationError {
        let nsError = error as NSError

        guard let laErrorCode = laErrorCode(for: nsError) else {
            return .failed(reason: error.localizedDescription)
        }

        switch laErrorCode {
        case .userCancel, .systemCancel, .appCancel:
            return .cancelled
        case .authenticationFailed:
            return .failed(reason: "Authentication failed. Try again.")
        case .biometryLockout:
            return .failed(reason: "Biometric authentication is locked. Use your device passcode to continue.")
        case .biometryNotAvailable:
            return .failed(reason: "Biometric authentication is not available on this device.")
        case .biometryNotEnrolled:
            return .failed(reason: "Biometric authentication is not enrolled on this device.")
        case .passcodeNotSet:
            return .failed(reason: "A device passcode is required to unlock Vault.")
        case .userFallback:
            return .failed(reason: "Complete authentication with your device passcode.")
        default:
            return .failed(reason: nsError.localizedDescription)
        }
    }

    private func laErrorCode(for error: NSError) -> LAError.Code? {
        guard error.domain == LAError.errorDomain else {
            return nil
        }

        return LAError.Code(rawValue: error.code)
    }
}
