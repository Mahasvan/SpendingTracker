import SwiftUI

struct DashboardView: View {
    @State var viewModel: DashboardViewModel
    @State private var editorPresented = false
    @State private var editing: Transaction?
    let txViewModel: TransactionsViewModel

    var body: some View {
        ScrollView {
            MasonryHStack(columns: 2, spacing: 16) {
                SummaryCardWidget(summary: viewModel.summary)
                SpendingTrendWidget(data: viewModel.dailySpend)
                TopCategoriesWidget(breakdown: viewModel.topCategories)
                BudgetBurnDownWidget(statuses: viewModel.budgetStatuses)
                PaymentMethodBreakdownWidget(data: viewModel.pmBreakdown)
                RecentTransactionsWidget(txs: viewModel.recent) { tx in editing = tx }
                LargestTransactionWidget(tx: viewModel.summary.largestExpense)
                CompareLastMonthWidget(deltas: viewModel.compareLastMonth)
            }
            .padding(16)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem {
                Button {
                    txViewModel.load()
                    editorPresented = true
                } label: { Label("Quick Add", systemImage: "plus") }
                .keyboardShortcut("n", modifiers: [.command])
                .help("Add a new transaction (⌘N)")
            }
        }
        .onAppear {
            txViewModel.load()
            viewModel.load()
        }
        .sheet(isPresented: $editorPresented) {
            NavigationStack {
                TransactionEditorView(
                    mode: .create,
                    categories: txViewModel.categories,
                    paymentMethods: txViewModel.paymentMethods,
                    onSave: { tx in
                        txViewModel.addTransaction(tx)
                        viewModel.load()
                    },
                    onDelete: nil
                )
            }
        }
        .sheet(item: $editing) { tx in
            NavigationStack {
                TransactionEditorView(
                    mode: .edit(tx),
                    categories: txViewModel.categories,
                    paymentMethods: txViewModel.paymentMethods,
                    onSave: { edited in
                        txViewModel.saveEdited(edited)
                        viewModel.load()
                    },
                    onDelete: { tx in
                        txViewModel.delete(tx)
                        viewModel.load()
                    }
                )
            }
        }
    }
}

#if DEBUG
@MainActor
private struct DashboardViewPreview: View {
    let dashVM: DashboardViewModel
    let txVM: TransactionsViewModel
    init() {
        let container = PreviewSupport.makeContainer()
        _ = PreviewSupport.seedSampleTransactions(in: container.modelContainer)
        let budgetsVM = BudgetsViewModel(
            repo: container.budgetRepo, txRepo: container.transactionRepo,
            categoryRepo: container.categoryRepo
        )
        dashVM = DashboardViewModel(txRepo: container.transactionRepo, budgetsVM: budgetsVM)
        txVM = TransactionsViewModel(
            repo: container.transactionRepo, categoryRepo: container.categoryRepo,
            pmRepo: container.paymentMethodRepo
        )
    }
    var body: some View {
        NavigationStack { DashboardView(viewModel: dashVM, txViewModel: txVM) }
            .frame(width: 800, height: 600)
    }
}

#Preview { DashboardViewPreview() }
#endif
