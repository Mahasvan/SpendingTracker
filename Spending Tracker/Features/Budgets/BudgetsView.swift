import SwiftUI

struct BudgetsView: View {
    @State var viewModel: BudgetsViewModel
    @State private var editorPresented = false
    @State private var pickedCategoryId: UUID?
    @State private var amountStr: String = ""
    @State private var editingExisting = false
    @State private var rangePickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Budgets").font(.title2.bold())
                Spacer()
                rangeMenu
                Button {
                    pickedCategoryId = viewModel.categories.first?.id
                    amountStr = ""
                    editingExisting = false
                    editorPresented = true
                } label: {
                    Label("Add Budget", systemImage: "plus")
                }
                .help("Create a new monthly budget")
            }
            Text("Showing: \(viewModel.rangeSelection.displayLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.statuses.isEmpty {
                ContentUnavailableView(
                    "No budgets yet",
                    systemImage: "chart.pie",
                    description: Text("Add a monthly budget per category to track spending.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.statuses) { st in
                        BudgetRow(status: st)
                            .contentShape(Rectangle())
                            .onTapGesture { beginEdit(status: st) }
                            .contextMenu {
                                Button {
                                    beginEdit(status: st)
                                } label: { Label("Edit", systemImage: "pencil") }
                                Button(role: .destructive) {
                                    if let b = viewModel.budgets.first(where: { $0.category?.id == st.categoryId }) {
                                        viewModel.delete(b)
                                    }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
                .listStyle(.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Budgets")
        .onAppear { viewModel.load() }
        .sheet(isPresented: $editorPresented) {
            BudgetEditorSheet(
                categories: viewModel.categories,
                pickedCategoryId: $pickedCategoryId,
                amountStr: $amountStr,
                isEditing: editingExisting,
                onSave: {
                    if let cid = pickedCategoryId, let amount = CurrencyFormatter.parse(amountStr) {
                        viewModel.addOrUpdate(categoryId: cid, amount: amount)
                    }
                    editorPresented = false
                },
                onCancel: { editorPresented = false }
            )
        }
        .sheet(isPresented: $rangePickerPresented) {
            BudgetRangeSheet(
                current: viewModel.rangeSelection,
                onApply: { sel in
                    viewModel.setRange(sel)
                    rangePickerPresented = false
                },
                onCancel: { rangePickerPresented = false }
            )
        }
    }

    private var rangeMenu: some View {
        Menu {
            Button("This Month") { viewModel.setRange(.thisMonth) }
            Button("Last Month") { viewModel.setRange(.lastMonth) }
            Divider()
            Button("Pick Month / Custom Range…") {
                rangePickerPresented = true
            }
        } label: {
            Label(viewModel.rangeSelection.displayLabel, systemImage: "calendar")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Change the period used to evaluate spending")
    }

    private func beginEdit(status: BudgetStatus) {
        pickedCategoryId = status.categoryId
        amountStr = CurrencyFormatter.editString(status.limit)
        editingExisting = true
        editorPresented = true
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
    let isEditing: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if isEditing, let cid = pickedCategoryId,
                   let cat = categories.first(where: { $0.id == cid }) {
                    LabeledContent("Category", value: cat.name)
                } else {
                    Picker("Category", selection: $pickedCategoryId) {
                        ForEach(categories, id: \.id) { c in
                            Text(c.name).tag(Optional(c.id))
                        }
                    }
                }
                TextField("Monthly limit (INR)", text: $amountStr)
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Budget" : "Add Budget")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 220)
    }

    private var canSave: Bool {
        guard pickedCategoryId != nil else { return false }
        guard let amount = CurrencyFormatter.parse(amountStr), amount > 0 else { return false }
        return true
    }
}

private struct BudgetRangeSheet: View {
    let current: BudgetRangeSelection
    let onApply: (BudgetRangeSelection) -> Void
    let onCancel: () -> Void

    @State private var mode: Mode = .month
    @State private var monthDate: Date = .now
    @State private var customStart: Date = .now
    @State private var customEnd: Date = .now

    private enum Mode: String, CaseIterable, Identifiable {
        case month = "Specific Month"
        case custom = "Custom Range"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .month {
                    DatePicker(
                        "Month",
                        selection: $monthDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.field)
                    Text("The full calendar month containing the chosen date will be used.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    DatePicker("Start", selection: $customStart, displayedComponents: [.date])
                    DatePicker("End", selection: $customEnd, in: customStart..., displayedComponents: [.date])
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Period")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { onApply(buildSelection()) }
                        .disabled(!canApply)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 260)
        .onAppear { hydrate(from: current) }
    }

    private var canApply: Bool {
        mode == .month || customEnd >= customStart
    }

    private func buildSelection() -> BudgetRangeSelection {
        switch mode {
        case .month:
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: monthDate)
            return .specificMonth(year: comps.year ?? 1970, month: comps.month ?? 1)
        case .custom:
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: customStart)
            let endOfDay = cal.date(byAdding: DateComponents(day: 1, second: -1), to: cal.startOfDay(for: customEnd)) ?? customEnd
            return .custom(start: startOfDay, end: endOfDay)
        }
    }

    private func hydrate(from selection: BudgetRangeSelection) {
        switch selection {
        case .thisMonth:
            mode = .month
            monthDate = .now
        case .lastMonth:
            mode = .month
            monthDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
        case .specificMonth(let y, let m):
            mode = .month
            var comps = DateComponents()
            comps.year = y; comps.month = m; comps.day = 1
            monthDate = Calendar.current.date(from: comps) ?? .now
        case .custom(let s, let e):
            mode = .custom
            customStart = s
            customEnd = e
        }
    }
}
