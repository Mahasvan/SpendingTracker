import SwiftUI

struct RootView: View {
    let container: AppContainer
    @State private var route: SidebarRoute? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(SidebarRoute.allCases, selection: $route) { r in
                NavigationLink(value: r) {
                    Label(r.title, systemImage: r.systemImage)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .navigationTitle("Spending Tracker")
        } detail: {
            detail
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch route {
        case .dashboard, .none:
            DashboardView(
                viewModel: container.dashboardVM,
                txViewModel: container.transactionsVM
            )
        case .transactions:
            TransactionListView(viewModel: container.transactionsVM)
        case .search:
            SearchView(viewModel: container.searchVM)
        case .budgets:
            BudgetsView(viewModel: container.budgetsVM)
        case .chatbot:
            ChatView(service: container.chatService, settings: container.settings)
        case .settings:
            SettingsView(
                categoryRepo: container.categoryRepo,
                pmRepo: container.paymentMethodRepo,
                settings: container.settings,
                importExportService: container.importExportService
            )
        }
    }
}
