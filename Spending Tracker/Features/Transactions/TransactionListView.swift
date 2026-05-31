import SwiftUI

struct TransactionListView: View {
    @State var viewModel: TransactionsViewModel
    @State private var editorPresented = false
    @State private var editing: Transaction?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.transactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "tray",
                    description: Text("Press ⌘N to add your first transaction.")
                )
            } else {
                List {
                    ForEach(viewModel.transactions, id: \.id) { tx in
                        TransactionRowView(transaction: tx)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = tx }
                            .contextMenu {
                                Button("Edit") { editing = tx }
                                Button("Delete", role: .destructive) { viewModel.delete(tx) }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem {
                Button { editorPresented = true } label: {
                    Label("Add", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .onAppear { viewModel.load() }
        .sheet(isPresented: $editorPresented) {
            NavigationStack {
                TransactionEditorView(
                    mode: .create,
                    categories: viewModel.categories,
                    paymentMethods: viewModel.paymentMethods,
                    onSave: { tx in
                        viewModel.addTransaction(tx)
                    },
                    onDelete: nil
                )
            }
        }
        .sheet(item: $editing) { tx in
            NavigationStack {
                TransactionEditorView(
                    mode: .edit(tx),
                    categories: viewModel.categories,
                    paymentMethods: viewModel.paymentMethods,
                    onSave: { edited in
                        viewModel.saveEdited(edited)
                    },
                    onDelete: { tx in
                        viewModel.delete(tx)
                    }
                )
            }
        }
    }
}
