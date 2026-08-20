import Foundation

/// Tool that categorizes transactions using Apple's on-device Foundation Models.
///
/// Self-contained: fetches the live category list, runs the model in chunked
/// batches (see `TransactionCategorizer`), and applies the results directly.
/// The chatbot can call this single tool instead of `get_categories` + manual
/// assignment. It is a `.write` tool, so the user's write-confirm policy gates
/// bulk application.
struct CategorizeTransactionsTool: Tool {
    let name = "categorize_transactions"
    let description = """
    Automatically assign categories to transactions using Apple Intelligence. \
    By default processes transactions that have no category yet (scope=uncategorized). \
    Set scope=all to re-categorize every transaction (overwrites existing categories). \
    Returns a summary of how many were categorized and skipped.
    """
    let kind: ToolKind = .write

    private static let defaultLimit = 100
    private static let maxLimit = 500

    var parameters: JSONValue {
        JSONSchemaBuilder.object(
            properties: [
                "scope": JSONSchemaBuilder.string(
                    "Which transactions to process",
                    enumValues: ["uncategorized", "all"]
                ),
                "limit": JSONSchemaBuilder.integer("Max transactions to process (default 100, capped at 500)")
            ]
        )
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        guard #available(macOS 26.0, iOS 26.0, *) else {
            throw ToolError.invalidArgument("categorize_transactions", reason: "requires macOS 26 / iOS 26 with Apple Intelligence")
        }

        let status = AppleFoundationIntrospection.checkAvailability()
        guard status.isAvailable else {
            throw ToolError.invalidArgument("categorize_transactions", reason: status.description)
        }

        let scopeStr = ToolArgs.string(args, "scope") ?? "uncategorized"
        let scopeAll = scopeStr == "all"
        let requested = ToolArgs.int(args, "limit") ?? Self.defaultLimit
        let limit = min(max(1, requested), Self.maxLimit)

        // Fetch a generous window and filter in-memory; TransactionQuery has no
        // "uncategorized" predicate. Date-descending so newest get categorized first.
        var q = TransactionQuery()
        q.limit = scopeAll ? limit : limit * 2
        q.sortBy = .dateDescending
        let fetched = try ctx.transactionRepo.fetch(q)
        let txs = (scopeAll ? fetched : fetched.filter { $0.category == nil }).prefix(limit)
        let targets = Array(txs)

        guard !targets.isEmpty else {
            return .object([
                "processed": .number(0),
                "categorized": .number(0),
                "skipped": .number(0),
                "batches": .number(0),
                "message": .string("No transactions to categorize.")
            ])
        }

        let categories = try ctx.categoryRepo.all(includeArchived: false).map(\.name)
        guard !categories.isEmpty else {
            throw ToolError.invalidArgument("categorize_transactions", reason: "no categories configured")
        }
        let lastResort = categories.last { $0.lowercased() == "other" } ?? categories.last

        let categorizer = TransactionCategorizer()
        let summary = try await categorizer.categorize(
            targets,
            categories: categories,
            lastResort: lastResort
        ) { uuid, categoryName in
            guard let tx = try ctx.transactionRepo.find(id: uuid) else { return }
            guard let cat = try ctx.categoryRepo.findByName(categoryName) else { return }
            tx.category = cat
            try ctx.transactionRepo.update(tx)
        }

        let samples: JSONValue = .array(summary.samples.map { s in
            .object([
                "id": .string(s.id.uuidString),
                "note": .string(s.note),
                "category": .string(s.category)
            ])
        })

        return .object([
            "processed": .number(Double(summary.processed)),
            "categorized": .number(Double(summary.categorized)),
            "skipped": .number(Double(summary.skipped)),
            "batches": .number(Double(summary.batches)),
            "samples": samples
        ])
    }
}
