import SwiftUI

struct BudgetsView: View {
    @State var viewModel: BudgetsViewModel
    @State private var editorPresented = false
    @State private var pickedCategoryId: UUID?
    @State private var amountStr: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Monthly Budgets").font(.title2.bold())
                Spacer()
                Button {
                    pickedCategoryId = viewModel.categories.first?.id
                    amountStr = ""
                    editorPresented = true
                } label: {
                    Label("Add Budget", systemImage: "plus")
                }
            }
            if viewModel.statuses.isEmpty {
                ContentUnavailableView(
                    "No budgets yet",
                    systemImage: "chart.pie",
                    description: Text("Add a monthly budget per category to track spending.")
                )
            } else {
                List {
                    ForEach(viewModel.statuses) { st in
                        BudgetRow(status: st)
                            .contextMenu {
                                Button(role: .destructive) {
                                    if let b = viewModel.budgets.first(where: { $0.category?.id == st.categoryId }) {
                                        viewModel.delete(b)
                                    }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .navigationTitle("Budgets")
        .onAppear { viewModel.load() }
        .sheet(isPresented: $editorPresented) {
            BudgetEditorSheet(
                categories: viewModel.categories,
                pickedCategoryId: $pickedCategoryId,
                amountStr: $amountStr,
                onSave: {
                    if let cid = pickedCategoryId, let amount = CurrencyFormatter.parse(amountStr) {
                        viewModel.addOrUpdate(categoryId: cid, amount: amount)
                    }
                    editorPresented = false
                },
                onCancel: { editorPresented = false }
            )
        }
    }
}

private struct BudgetRow: View {
    let status: BudgetStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(status.categoryName).font(.headline)
                Spacer()
                Text("\(CurrencyFormatter.format(status.spent)) / \(CurrencyFormatter.format(status.limit))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(status.percent, 1.0))
                .tint(barColor)
            HStack {
                Text("\(Int(status.percent * 100))% used")
                Spacer()
                Text("\(CurrencyFormatter.format(max(0, status.remaining))) left")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var barColor: Color {
        switch status.percent {
        case ..<0.7: return .green
        case ..<1.0: return .orange
        default: return .red
        }
    }
}

private struct BudgetEditorSheet: View {
    let categories: [Category]
    @Binding var pickedCategoryId: UUID?
    @Binding var amountStr: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Form {
            Picker("Category", selection: $pickedCategoryId) {
                ForEach(categories, id: \.id) { c in
                    Text(c.name).tag(Optional(c.id))
                }
            }
            TextField("Monthly limit (INR)", text: $amountStr)
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 400, minHeight: 200)
        .toolbar {
            ToolbarItemGroup(placement: .confirmationAction) {
                Button("Save", action: onSave)
            }
            ToolbarItemGroup(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
        }
    }
}
