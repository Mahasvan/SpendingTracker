import SwiftUI
import SwiftData

@main
struct Spending_TrackerApp: App {
    @State private var container: AppContainer

    init() {
        let modelContainer = PersistenceController.makeContainer(inMemory: false)
        _container = State(initialValue: AppContainer(modelContainer: modelContainer))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
        .modelContainer(container.modelContainer)
        .windowResizability(.contentSize)
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
