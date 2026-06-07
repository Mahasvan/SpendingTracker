import LocalAuthentication
import SwiftUI

struct ContentView: View {
    let container: AppContainer
    @State private var lock: AppLockService
    @State private var isLoadingVault = false
    @State private var vaultError: String?
    @State private var showAlert = false

    init(container: AppContainer) {
        self.container = container
        _lock = State(initialValue: AppLockService(settings: container.settings))
    }

    var body: some View {
        Group {
            if isLoadingVault {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Decrypting vault...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lock.isUnlocked {
                RootView(container: container)
            } else {
                LockView(lock: lock)
            }
        }
        .alert("Vault Error", isPresented: $showAlert) {
            Button("OK") { vaultError = nil }
        } message: {
            if let error = vaultError {
                Text(error)
            }
        }
        .task {
            await lock.authenticate()
            if lock.isUnlocked {
                // If lock is disabled, create a fresh LAContext for key access
                let authContext = lock.authContext ?? LAContext()
                await loadVault(authContext: authContext)
            }
        }
    }

    private func loadVault(authContext: LAContext) async {
        isLoadingVault = true
        defer { isLoadingVault = false }

        do {
            try container.loadVault(authContext: authContext)
        } catch {
            vaultError = error.localizedDescription
            showAlert = true
        }
    }
}
