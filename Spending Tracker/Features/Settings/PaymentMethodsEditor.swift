import SwiftUI

struct PaymentMethodsEditor: View {
    let repo: any PaymentMethodRepository

    private enum EditorMode: Identifiable {
        case add
        case edit(PaymentMethod)
        var id: String {
            switch self {
            case .add: return "__add__"
            case .edit(let pm): return pm.id.uuidString
            }
        }
        var existing: PaymentMethod? {
            if case .edit(let pm) = self { return pm }
            return nil
        }
    }

    @State private var items: [PaymentMethod] = []
    @State private var editorMode: EditorMode?
    @State private var showArchived = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if items.isEmpty {
                ContentUnavailableView(
                    "No payment methods",
                    systemImage: "creditcard",
                    description: Text("Add the ways you pay so transactions can reference them.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    activeSection
                    archivedSection
                }
                .listStyle(.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let e = error {
                Text(e).font(.caption).foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { reload() }
        .sheet(item: $editorMode) { mode in
            PaymentMethodEditorSheet(
                existing: mode.existing,
                onSave: { draft in
                    persist(draft)
                    editorMode = nil
                },
                onCancel: {
                    editorMode = nil
                }
            )
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Payment Methods").font(.title2.bold())
            Spacer()
            Button {
                editorMode = .add
            } label: {
                Label("Add Payment Method", systemImage: "plus")
            }
            .help("Create a new payment method")
        }
    }

    private var activeItems: [PaymentMethod] {
        items.filter { !$0.archived }
    }

    private var archivedItems: [PaymentMethod] {
        items.filter { $0.archived }
    }

    @ViewBuilder
    private var activeSection: some View {
        Section {
            ForEach(activeItems, id: \.id) { pm in
                row(for: pm)
            }
        } header: {
            Text("Active (\(activeItems.count))")
        }
    }

    @ViewBuilder
    private var archivedSection: some View {
        if !archivedItems.isEmpty {
            Section {
                if showArchived {
                    ForEach(archivedItems, id: \.id) { pm in
                        row(for: pm)
                    }
                }
            } header: {
                DisclosureGroup(isExpanded: $showArchived) {
                    EmptyView()
                } label: {
                    Text("Archived (\(archivedItems.count))")
                }
            }
        }
    }

    private func row(for pm: PaymentMethod) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background.tertiary)
                    .frame(width: 36, height: 36)
                Image(systemName: pm.kind.systemImage)
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(pm.name)
                    .strikethrough(pm.archived)
                    .foregroundStyle(pm.archived ? .secondary : .primary)
                Text(pm.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            actionMenu(for: pm)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            beginEdit(pm)
        }
        .contextMenu {
            Button {
                beginEdit(pm)
            } label: { Label("Edit", systemImage: "pencil") }
            if pm.archived {
                Button {
                    setArchived(pm, archived: false)
                } label: { Label("Unarchive", systemImage: "arrow.up.bin") }
            } else {
                Button {
                    setArchived(pm, archived: true)
                } label: { Label("Archive", systemImage: "archivebox") }
            }
            Divider()
            Button(role: .destructive) {
                delete(pm)
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func actionMenu(for pm: PaymentMethod) -> some View {
        Menu {
            Button {
                beginEdit(pm)
            } label: { Label("Edit", systemImage: "pencil") }
            if pm.archived {
                Button {
                    setArchived(pm, archived: false)
                } label: { Label("Unarchive", systemImage: "arrow.up.bin") }
            } else {
                Button {
                    setArchived(pm, archived: true)
                } label: { Label("Archive", systemImage: "archivebox") }
            }
            Divider()
            Button(role: .destructive) {
                delete(pm)
            } label: { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func beginEdit(_ pm: PaymentMethod) {
        editorMode = .edit(pm)
    }

    private func persist(_ draft: PaymentMethodDraft) {
        do {
            if let existing = draft.target {
                existing.name = draft.name
                existing.kind = draft.kind
                try repo.update(existing)
            } else {
                try repo.add(PaymentMethod(name: draft.name, kind: draft.kind))
            }
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func setArchived(_ pm: PaymentMethod, archived: Bool) {
        pm.archived = archived
        do {
            try repo.update(pm)
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ pm: PaymentMethod) {
        do {
            try repo.delete(id: pm.id)
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func reload() {
        do {
            items = try repo.all(includeArchived: true)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct PaymentMethodDraft {
    var target: PaymentMethod?
    var name: String
    var kind: PMKind
}

private struct PaymentMethodEditorSheet: View {
    let existing: PaymentMethod?
    let onSave: (PaymentMethodDraft) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var kind: PMKind = .other

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                }
                Section("Kind") {
                    Picker("Kind", selection: $kind) {
                        ForEach(PMKind.allCases) { k in
                            Label(k.displayName, systemImage: k.systemImage).tag(k)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    livePreview
                } header: {
                    Text("Preview")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existing == nil ? "Add Payment Method" : "Edit Payment Method")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 380)
        .onAppear(perform: hydrate)
    }

    private var livePreview: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background.tertiary)
                    .frame(width: 44, height: 44)
                Image(systemName: kind.systemImage)
                    .foregroundStyle(.secondary)
                    .font(.title2)
            }
            VStack(alignment: .leading) {
                Text(name.isEmpty ? "Payment method name" : name)
                    .font(.headline)
                    .foregroundStyle(name.isEmpty ? .secondary : .primary)
                Text(kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        onSave(PaymentMethodDraft(
            target: existing,
            name: name.trimmingCharacters(in: .whitespaces),
            kind: kind
        ))
    }

    private func hydrate() {
        if let existing {
            name = existing.name
            kind = existing.kind
        }
    }
}
