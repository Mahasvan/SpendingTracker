import AppKit
import SwiftUI
import SwiftData

@main
struct Spending_TrackerApp: App {
    @State private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Use in-memory container for encrypted vault
        let modelContainer = PersistenceController.makeInMemoryContainer()
        _container = State(initialValue: AppContainer(modelContainer: modelContainer))

        // Register for app termination notification. The handler hops to the
        // main actor since snapshot() is MainActor-isolated.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [container] _ in
            MainActor.assumeIsolated {
                try? container.snapshot()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
        .modelContainer(container.modelContainer)
        .windowResizability(.contentSize)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                // Snapshot when app goes to background
                try? container.snapshot()
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Transaction") {
                    NotificationCenter.default.post(name: .newTransactionRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let newTransactionRequested = Notification.Name("newTransactionRequested")
}
