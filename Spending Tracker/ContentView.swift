import SwiftUI

struct ContentView: View {
    let container: AppContainer
    @State private var lock: AppLockService

    init(container: AppContainer) {
        self.container = container
        _lock = State(initialValue: AppLockService(settings: container.settings))
    }

    var body: some View {
        Group {
            if lock.isUnlocked {
                RootView(container: container)
            } else {
                LockView(lock: lock)
            }
        }
        .task {
            await lock.authenticate()
        }
    }
}

#if DEBUG
@MainActor
private struct ContentViewPreview: View {
    let container: AppContainer
    init() {
        container = PreviewSupport.makeContainer()
        _ = PreviewSupport.seedSampleTransactions(in: container.modelContainer)
    }
    var body: some View {
        ContentView(container: container)
            .frame(width: 900, height: 600)
    }
}

#Preview {
    ContentViewPreview()
}
#endif
