import SwiftUI

struct SecuritySettingsView: View {
    @Bindable var settings: AppSettings
    let container: AppContainer

    private let biometry = AppLockService.biometryDescription()

    var body: some View {
        Form {
            Section("App Lock") {
                Toggle("Require authentication on launch", isOn: $settings.requireBiometricUnlock)
                Text("Unlocks with \(biometry). The lock is applied the next time you open the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Data Encryption") {
                HStack {
                    Text("Vault encryption")
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                }

                if container.vaultCoordinator.isMigrationCompleted {
                    HStack {
                        Text("Migration completed")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack {
                        Text("Migration pending")
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Text("Your data is encrypted at rest using AES-256. The encryption key is stored in the Keychain and protected by biometrics or device password. If you lose device access, your data cannot be recovered without a manual JSON backup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Security")
    }
}
