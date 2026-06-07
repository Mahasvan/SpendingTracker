import SwiftUI

struct SecuritySettingsView: View {
    @Bindable var settings: AppSettings

    private let biometry = AppLockService.biometryDescription()

    var body: some View {
        Form {
            Section("App Lock") {
                Toggle("Require authentication on launch", isOn: $settings.requireBiometricUnlock)
                Text("Unlocks with \(biometry). The lock is applied the next time you open the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Security")
    }
}
