import SwiftUI

struct CategoriesEditor: View {
    let repo: any CategoryRepository

    private enum EditorMode: Identifiable {
        case add
        case edit(Category)
        var id: String {
            switch self {
            case .add: return "__add__"
            case .edit(let c): return c.id.uuidString
            }
        }
        var existing: Category? {
            if case .edit(let c) = self { return c }
            return nil
        }
    }

    @State private var categories: [Category] = []
    @State private var editorMode: EditorMode?
    @State private var showArchived = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if categories.isEmpty {
                ContentUnavailableView(
                    "No categories",
                    systemImage: "tag",
                    description: Text("Add your first category to start tagging transactions.")
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
            CategoryEditorSheet(
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
            Text("Categories").font(.title2.bold())
            Spacer()
            Button {
                editorMode = .add
            } label: {
                Label("Add Category", systemImage: "plus")
            }
            .help("Create a new category")
        }
    }

    private var activeCategories: [Category] {
        categories.filter { !$0.archived }
    }

    private var archivedCategories: [Category] {
        categories.filter { $0.archived }
    }

    @ViewBuilder
    private var activeSection: some View {
        Section {
            ForEach(activeCategories, id: \.id) { c in
                row(for: c)
            }
        } header: {
            Text("Active (\(activeCategories.count))")
        }
    }

    @ViewBuilder
    private var archivedSection: some View {
        if !archivedCategories.isEmpty {
            Section {
                if showArchived {
                    ForEach(archivedCategories, id: \.id) { c in
                        row(for: c)
                    }
                }
            } header: {
                DisclosureGroup(isExpanded: $showArchived) {
                    EmptyView()
                } label: {
                    Text("Archived (\(archivedCategories.count))")
                }
            }
        }
    }

    private func row(for c: Category) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: c.colorHex).opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: c.systemImage)
                    .foregroundStyle(Color(hex: c.colorHex))
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name)
                    .strikethrough(c.archived)
                    .foregroundStyle(c.archived ? .secondary : .primary)
                Text(c.systemImage)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            actionMenu(for: c)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            beginEdit(c)
        }
        .contextMenu {
            Button {
                beginEdit(c)
            } label: { Label("Edit", systemImage: "pencil") }
            if c.archived {
                Button {
                    setArchived(c, archived: false)
                } label: { Label("Unarchive", systemImage: "arrow.up.bin") }
            } else {
                Button {
                    setArchived(c, archived: true)
                } label: { Label("Archive", systemImage: "archivebox") }
            }
            Divider()
            Button(role: .destructive) {
                delete(c)
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func actionMenu(for c: Category) -> some View {
        Menu {
            Button {
                beginEdit(c)
            } label: { Label("Edit", systemImage: "pencil") }
            if c.archived {
                Button {
                    setArchived(c, archived: false)
                } label: { Label("Unarchive", systemImage: "arrow.up.bin") }
            } else {
                Button {
                    setArchived(c, archived: true)
                } label: { Label("Archive", systemImage: "archivebox") }
            }
            Divider()
            Button(role: .destructive) {
                delete(c)
            } label: { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func beginEdit(_ c: Category) {
        editorMode = .edit(c)
    }

    private func persist(_ draft: CategoryDraft) {
        do {
            if let existing = draft.target {
                existing.name = draft.name
                existing.colorHex = draft.colorHex
                existing.systemImage = draft.systemImage
                try repo.update(existing)
            } else {
                try repo.add(Category(
                    name: draft.name,
                    colorHex: draft.colorHex,
                    systemImage: draft.systemImage
                ))
            }
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func setArchived(_ c: Category, archived: Bool) {
        c.archived = archived
        do {
            try repo.update(c)
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ c: Category) {
        do {
            try repo.delete(id: c.id)
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func reload() {
        do {
            categories = try repo.all(includeArchived: true)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CategoryDraft {
    var target: Category?
    var name: String
    var colorHex: String
    var systemImage: String
}

private struct CategoryEditorSheet: View {
    let existing: Category?
    let onSave: (CategoryDraft) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var colorHex: String = "#888888"
    @State private var symbolName: String = "tag"
    @State private var color: Color = .gray

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                }
                Section("Appearance") {
                    HStack {
                        Text("Color")
                        Spacer()
                        ColorPicker("", selection: $color, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: color) { _, newValue in
                                colorHex = newValue.toHex() ?? colorHex
                            }
                    }
                    SymbolPicker(symbolName: $symbolName, tintColor: Color(hex: colorHex))
                }
                Section {
                    livePreview
                } header: {
                    Text("Preview")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existing == nil ? "Add Category" : "Edit Category")
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
        .frame(minWidth: 480, minHeight: 420)
        .onAppear(perform: hydrate)
    }

    private var livePreview: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: colorHex).opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: SymbolLibrary.isValid(symbolName) ? symbolName : "questionmark")
                    .foregroundStyle(Color(hex: colorHex))
                    .font(.title2)
            }
            VStack(alignment: .leading) {
                Text(name.isEmpty ? "Category name" : name)
                    .font(.headline)
                    .foregroundStyle(name.isEmpty ? .secondary : .primary)
                Text("\(colorHex) · \(symbolName)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }
            Spacer()
        }
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard SymbolLibrary.isValid(symbolName) else { return false }
        return true
    }

    private func save() {
        onSave(CategoryDraft(
            target: existing,
            name: name.trimmingCharacters(in: .whitespaces),
            colorHex: colorHex,
            systemImage: symbolName.trimmingCharacters(in: .whitespaces)
        ))
    }

    private func hydrate() {
        if let existing {
            name = existing.name
            colorHex = existing.colorHex
            symbolName = existing.systemImage
            color = Color(hex: existing.colorHex)
        }
    }
}
