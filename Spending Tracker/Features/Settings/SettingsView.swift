import SwiftUI

struct SettingsView: View {
    let categoryRepo: any CategoryRepository
    let pmRepo: any PaymentMethodRepository
    @Bindable var settings: AppSettings
    let importExportService: ImportExportService

    var body: some View {
        TabView {
            CategoriesEditor(repo: categoryRepo)
                .tabItem { Label("Categories", systemImage: "tag") }
            PaymentMethodsEditor(repo: pmRepo)
                .tabItem { Label("Payment Methods", systemImage: "creditcard") }
            LLMSettingsView(settings: settings)
                .tabItem { Label("LLM", systemImage: "brain") }
            BackupView(service: importExportService)
                .tabItem { Label("Backup", systemImage: "externaldrive") }
        }
        .frame(minWidth: 640, minHeight: 520)
        .navigationTitle("Settings")
    }
}
