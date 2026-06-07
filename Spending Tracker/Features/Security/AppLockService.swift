import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLockService {
    private let settings: AppSettings

    private(set) var isUnlocked: Bool
    private(set) var isAuthenticating = false
    var lastError: String?
    private(set) var authContext: LAContext?

    init(settings: AppSettings) {
        self.settings = settings
        // Start unlocked when the lock is disabled so the UI shows immediately.
        self.isUnlocked = !settings.requireBiometricUnlock
    }

    var isLockEnabled: Bool { settings.requireBiometricUnlock }

    /// Prompts for Touch ID / password. No-op when the lock is disabled or already unlocked.
    func authenticate() async {
        guard settings.requireBiometricUnlock, !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedFallbackTitle = "Enter Password"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastError = error?.localizedDescription ?? "Authentication is not available on this device."
            return
        }

        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Spending Tracker"
            )
            isUnlocked = ok
            if ok {
                lastError = nil
                authContext = context
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Human-readable name of the available authentication method, for settings copy.
    static func biometryDescription() -> String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return "unavailable"
        }
        switch context.biometryType {
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        default: return "your password"
        }
    }
}
