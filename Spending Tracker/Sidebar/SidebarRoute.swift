import Foundation

enum SidebarRoute: String, Hashable, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case search
    case budgets
    case chatbot
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .transactions: return "Transactions"
        case .search: return "Search"
        case .budgets: return "Budgets"
        case .chatbot: return "Chatbot"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .transactions: return "list.bullet.rectangle"
        case .search: return "magnifyingglass"
        case .budgets: return "chart.pie"
        case .chatbot: return "bubble.left.and.text.bubble.right"
        case .settings: return "gearshape"
        }
    }
}
