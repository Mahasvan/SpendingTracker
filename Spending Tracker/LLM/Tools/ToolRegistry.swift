import Foundation

@MainActor
final class ToolRegistry {
    private var tools: [String: any Tool] = [:]

    func register(_ tool: any Tool) {
        tools[tool.name] = tool
    }

    func schemas() -> [LLMToolSchema] {
        tools.values.map(\.schema).sorted { $0.name < $1.name }
    }

    func tool(named name: String) -> (any Tool)? {
        tools[name]
    }

    var all: [any Tool] { Array(tools.values) }

    static func defaultRegistry() -> ToolRegistry {
        let r = ToolRegistry()
        r.register(AddTransactionTool())
        r.register(UpdateTransactionTool())
        r.register(DeleteTransactionTool())
        r.register(ListTransactionsTool())
        r.register(SearchTransactionsTool())
        r.register(GetCategoriesTool())
        r.register(GetPaymentMethodsTool())
        r.register(CreateCategoryTool())
        r.register(CreatePaymentMethodTool())
        r.register(GetSummaryTool())
        r.register(GetBudgetStatusTool())
        r.register(GetCurrentDateTimeTool())
        r.register(CategorizeTransactionsTool())
        return r
    }
}
