import SwiftUI

struct SettingsView: View {
    let categoryRepo: any CategoryRepository
    let pmRepo: any PaymentMethodRepository
    @Bindable var settings: AppSettings
    let importExportService: ImportExportService
    let capabilityStore: ModelCapabilityStore

    var body: some View {
        TabView {
            CategoriesEditor(repo: categoryRepo)
                .tabItem { Label("Categories", systemImage: "tag") }
            PaymentMethodsEditor(repo: pmRepo)
                .tabItem { Label("Payment Methods", systemImage: "creditcard") }
            LLMSettingsView(settings: settings, store: capabilityStore)
                .tabItem { Label("LLM", systemImage: "brain") }
            SecuritySettingsView(settings: settings)
                .tabItem { Label("Security", systemImage: "lock") }
            BackupView(service: importExportService)
                .tabItem { Label("Backup", systemImage: "externaldrive") }
        }
        .frame(minWidth: 640, minHeight: 520)
        .navigationTitle("Settings")
    }
}

#if DEBUG
@MainActor
private struct SettingsViewPreview: View {
    let container: AppContainer
    init() { container = PreviewSupport.makeContainer() }
    var body: some View {
        NavigationStack {
            SettingsView(
                categoryRepo: container.categoryRepo,
                pmRepo: container.paymentMethodRepo,
                settings: container.settings,
                importExportService: container.importExportService,
                capabilityStore: container.capabilityStore
            )
        }
        .frame(width: 600, height: 600)
    }
}

#Preview { SettingsViewPreview() }
#endif
