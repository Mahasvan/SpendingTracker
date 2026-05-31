import SwiftUI

struct PaymentMethodsEditor: View {
    let repo: any PaymentMethodRepository
    @State private var items: [PaymentMethod] = []
    @State private var newName: String = ""
    @State private var newKind: PMKind = .other
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Methods").font(.title2.bold())
            HStack {
                TextField("Name", text: $newName)
                Picker("Kind", selection: $newKind) {
                    ForEach(PMKind.allCases) { k in Text(k.displayName).tag(k) }
                }
                .frame(width: 200)
                Button("Add") { add() }.disabled(newName.isEmpty)
            }
            List {
                ForEach(items, id: \.id) { pm in
                    HStack {
                        Image(systemName: pm.kind.systemImage)
                        Text(pm.name)
                        Spacer()
                        Text(pm.kind.displayName).foregroundStyle(.secondary)
                        Toggle("Archived", isOn: Binding(
                            get: { pm.archived },
                            set: { v in
                                pm.archived = v
                                try? repo.update(pm)
                            }
                        )).toggleStyle(.switch)
                        Button(role: .destructive) { delete(pm) } label: {
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
        do { items = try repo.all(includeArchived: true) }
        catch { error = error.localizedDescription }
    }

    private func add() {
        do {
            try repo.add(PaymentMethod(name: newName, kind: newKind))
            newName = ""; newKind = .other
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
}
