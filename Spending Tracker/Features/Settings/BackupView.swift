import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    let service: ImportExportService

    @State private var exportPresented = false
    @State private var importPresented = false
    @State private var exportDocument: BackupDocument?
    @State private var importMode: ImportMode = .merge
    @State private var lastSummary: ImportSummary?
    @State private var error: String?
    @State private var includeChatHistory: Bool = true

    var body: some View {
        Form {
            Section("Export") {
                Toggle("Include chat history", isOn: $includeChatHistory)
                HStack {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export to JSON…", systemImage: "square.and.arrow.up")
                    }
                    Spacer()
                }
                Text("Exports all transactions, categories, payment methods, and budgets to a single JSON file. Chat history is optional.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Import") {
                Picker("Mode", selection: $importMode) {
                    ForEach(ImportMode.allCases) { m in Text(m.displayName).tag(m) }
                }
                HStack {
                    Button {
                        importPresented = true
                    } label: {
                        Label("Import from JSON…", systemImage: "square.and.arrow.down")
                    }
                    Spacer()
                }
                if importMode == .merge {
                    Text("Merge: existing rows are kept and updated where the imported file has the same id; categories and payment methods also dedupe by name to avoid duplicate tags. Net effect is the union of both datasets.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Replace: all local data is wiped first, then the file is imported. Cannot be undone.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            if let s = lastSummary {
                Section("Last import summary") {
                    if s.deletedBeforeReplace > 0 {
                        KeyValueRow(key: "Deleted before replace", value: "\(s.deletedBeforeReplace)")
                    }
                    KeyValueRow(key: "Categories upserted", value: "\(s.categoriesUpserted)")
                    KeyValueRow(key: "Payment methods upserted", value: "\(s.paymentMethodsUpserted)")
                    KeyValueRow(key: "Transactions upserted", value: "\(s.transactionsUpserted)")
                    KeyValueRow(key: "Budgets upserted", value: "\(s.budgetsUpserted)")
                    KeyValueRow(key: "Chat sessions upserted", value: "\(s.chatSessionsUpserted)")
                }
            }
            if let err = error {
                Section { Text(err).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Import / Export")
        .fileExporter(
            isPresented: $exportPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: defaultFilename
        ) { result in
            switch result {
            case .success: error = nil
            case .failure(let e): error = e.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $importPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    private var defaultFilename: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return "spending-tracker-backup-\(f.string(from: .now))"
    }

    private func prepareExport() {
        do {
            let data = try service.exportAll(includeChatHistory: includeChatHistory)
            exportDocument = BackupDocument(data: data)
            exportPresented = true
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let summary = try service.importBackup(data, mode: importMode)
            lastSummary = summary
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String
    var body: some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = d
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#if DEBUG
@MainActor
private struct BackupViewPreview: View {
    let service: ImportExportService
    init() {
        let container = PreviewSupport.makeContainer()
        service = container.importExportService
    }
    var body: some View {
        BackupView(service: service)
            .frame(width: 500, height: 400)
    }
}

#Preview { BackupViewPreview() }
#endif
