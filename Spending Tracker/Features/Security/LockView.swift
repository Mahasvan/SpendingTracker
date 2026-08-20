import SwiftUI

struct LockView: View {
    @Bindable var lock: AppLockService

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Spending Tracker is locked")
                .font(.title2.bold())
            Text("Authenticate to access your data.")
                .foregroundStyle(.secondary)

            if let err = lock.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await lock.authenticate() }
            } label: {
                if lock.isAuthenticating {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Unlock", systemImage: "touchid")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(lock.isAuthenticating)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 420, minHeight: 320)
    }
}

#if DEBUG
#Preview {
    LockView(lock: AppLockService(settings: PreviewSupport.makeSettings()))
}
#endif
