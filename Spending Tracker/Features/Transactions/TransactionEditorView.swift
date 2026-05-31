import SwiftUI

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let categories: [Category]
    let paymentMethods: [PaymentMethod]
    let onSave: (Transaction) -> Void
    let onDelete: ((Transaction) -> Void)?

    @State private var amountString: String = ""
    @State private var type: TxType = .expense
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedPMId: UUID?
    @State private var errorMessage: String?

    enum Mode {
        case create
        case edit(Transaction)

        var title: String {
            switch self {
            case .create: return "New Transaction"
            case .edit: return "Edit Transaction"
            }
        }
    }

    var body: some View {
        Form {
            Section("Details") {
                Picker("Type", selection: $type) {
                    ForEach(TxType.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                TextField("Amount (INR)", text: $amountString)
                    .textFieldStyle(.roundedBorder)

                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                Picker("Category", selection: $selectedCategoryId) {
                    Text("None").tag(UUID?.none)
                    ForEach(categories) { c in
                        Text(c.name).tag(Optional(c.id))
                    }
                }

                Picker("Payment Method", selection: $selectedPMId) {
                    Text("None").tag(UUID?.none)
                    ForEach(paymentMethods) { pm in
                        Text(pm.name).tag(Optional(pm.id))
                    }
                }
            }
            Section("Note") {
                TextEditor(text: $note)
                    .frame(minHeight: 80)
            }
            if let msg = errorMessage {
                Section { Text(msg).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItemGroup(placement: .confirmationAction) {
                Button("Save") { save() }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            ToolbarItemGroup(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            if case .edit(let tx) = mode, let onDelete {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        onDelete(tx)
                        dismiss()
                    } label: { Text("Delete") }
                }
            }
        }
        .onAppear(perform: prefill)
        .frame(minWidth: 480, minHeight: 480)
    }

    private func prefill() {
        switch mode {
        case .create:
            break
        case .edit(let tx):
            amountString = NSDecimalNumber(decimal: tx.amount).stringValue
            type = tx.type
            date = tx.date
            note = tx.note
            selectedCategoryId = tx.category?.id
            selectedPMId = tx.paymentMethod?.id
        }
    }

    private func save() {
        guard let amount = CurrencyFormatter.parse(amountString), amount > 0 else {
            errorMessage = "Enter a valid amount"
            return
        }
        let category = categories.first { $0.id == selectedCategoryId }
        let pm = paymentMethods.first { $0.id == selectedPMId }
        let tx: Transaction
        switch mode {
        case .create:
            tx = Transaction(
                amount: amount,
                type: type,
                date: date,
                note: note,
                category: category,
                paymentMethod: pm
            )
        case .edit(let existing):
            existing.amount = amount
            existing.type = type
            existing.date = date
            existing.note = note
            existing.category = category
            existing.paymentMethod = pm
            tx = existing
        }
        onSave(tx)
        dismiss()
    }
}
