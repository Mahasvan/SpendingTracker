import SwiftUI

struct CategoriesEditor: View {
    let repo: any CategoryRepository
    @State private var categories: [Category] = []
    @State private var newName: String = ""
    @State private var newColor: String = "#888888"
    @State private var newIcon: String = "tag"
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories").font(.title2.bold())
            HStack {
                TextField("Name", text: $newName)
                TextField("Color (#RRGGBB)", text: $newColor).frame(width: 130)
                TextField("Icon (SF Symbol)", text: $newIcon).frame(width: 160)
                Button("Add") { add() }.disabled(newName.isEmpty)
            }
            List {
                ForEach(categories, id: \.id) { c in
                    HStack {
                        Image(systemName: c.systemImage).foregroundStyle(Color(hex: c.colorHex))
                        Text(c.name)
                        Spacer()
                        Toggle("Archived", isOn: Binding(
                            get: { c.archived },
                            set: { newVal in
                                c.archived = newVal
                                try? repo.update(c)
                            }
                        )).toggleStyle(.switch)
                        Button(role: .destructive) { delete(c) } label: {
                            Image(systemName: "trash")
                        }.buttonStyle(.borderless)
                    }
                }
            }
            if let e = error { Text(e).foregroundStyle(.red) }
        }
        .padding()
        .onAppear { reload() }
    }

    private func reload() {
        do { categories = try repo.all(includeArchived: true) }
        catch { error = error.localizedDescription }
    }

    private func add() {
        do {
            try repo.add(Category(name: newName, colorHex: newColor, systemImage: newIcon))
            newName = ""; newColor = "#888888"; newIcon = "tag"
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
}
