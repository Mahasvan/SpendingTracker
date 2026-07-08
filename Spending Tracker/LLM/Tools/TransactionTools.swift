import Foundation

struct AddTransactionTool: Tool {
    let name = "add_transaction"
    let description = "Add a new transaction (expense or income). Returns the created transaction's ID."
    let kind: ToolKind = .write
    var parameters: JSONValue {
        JSONSchemaBuilder.object(
            properties: [
                "amount": JSONSchemaBuilder.number("Amount in INR (positive)"),
                "type": JSONSchemaBuilder.string("Transaction type", enumValues: ["expense", "income"]),
                "date": JSONSchemaBuilder.string("ISO-8601 date or date-time, e.g. 2026-06-02 or 2026-06-02T15:30 (defaults to now if omitted). Include the time whenever the user specifies or implies one."),
                "note": JSONSchemaBuilder.string("Optional note"),
                "category": JSONSchemaBuilder.string("Category name (must exist)"),
                "payment_method": JSONSchemaBuilder.string("Payment method name (must exist)")
            ],
            required: ["amount", "type"]
        )
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        guard let amount = ToolArgs.decimal(args, "amount"), amount > 0 else {
            throw ToolError.invalidArgument("amount", reason: "must be positive number")
        }
        guard let typeStr = ToolArgs.string(args, "type"),
              let type = TxType(rawValue: typeStr) else {
            throw ToolError.invalidArgument("type", reason: "must be 'expense' or 'income'")
        }
        let date = ToolArgs.date(args, "date") ?? .now
        let note = ToolArgs.string(args, "note") ?? ""

        var category: Category?
        if let catName = ToolArgs.string(args, "category"), !catName.isEmpty {
            category = try ctx.categoryRepo.findByName(catName)
            if category == nil { throw ToolError.notFound("Category '\(catName)'") }
        }
        var pm: PaymentMethod?
        if let pmName = ToolArgs.string(args, "payment_method"), !pmName.isEmpty {
            pm = try ctx.paymentMethodRepo.findByName(pmName)
            if pm == nil { throw ToolError.notFound("Payment method '\(pmName)'") }
        }
        let tx = Transaction(
            amount: amount,
            type: type,
            date: date,
            note: note,
            category: category,
            paymentMethod: pm
        )
        try ctx.transactionRepo.add(tx)
        return .string(tx.id.uuidString)
    }
}

struct UpdateTransactionTool: Tool {
    let name = "update_transaction"
    let description = "Update an existing transaction by id. Only provided fields are changed."
    let kind: ToolKind = .write
    var parameters: JSONValue {
        JSONSchemaBuilder.object(
            properties: [
                "id": JSONSchemaBuilder.string("Transaction UUID"),
                "amount": JSONSchemaBuilder.number("New amount"),
                "type": JSONSchemaBuilder.string("New type", enumValues: ["expense", "income"]),
                "date": JSONSchemaBuilder.string("New ISO-8601 date or date-time, e.g. 2026-06-02T15:30. Include the time when provided."),
                "note": JSONSchemaBuilder.string("New note"),
                "category": JSONSchemaBuilder.string("New category name"),
                "payment_method": JSONSchemaBuilder.string("New payment method name")
            ],
            required: ["id"]
        )
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        guard let id = ToolArgs.uuid(args, "id") else {
            throw ToolError.invalidArgument("id", reason: "must be UUID")
        }
        guard let tx = try ctx.transactionRepo.find(id: id) else {
            throw ToolError.notFound("Transaction \(id)")
        }
        if let amount = ToolArgs.decimal(args, "amount") { tx.amount = amount }
        if let typeStr = ToolArgs.string(args, "type"), let t = TxType(rawValue: typeStr) { tx.type = t }
        if let date = ToolArgs.date(args, "date") { tx.date = date }
        if let note = ToolArgs.string(args, "note") { tx.note = note }
        if let cName = ToolArgs.string(args, "category"), !cName.isEmpty {
            guard let cat = try ctx.categoryRepo.findByName(cName) else {
                throw ToolError.notFound("Category '\(cName)'")
            }
            tx.category = cat
        }
        if let pName = ToolArgs.string(args, "payment_method"), !pName.isEmpty {
            guard let pm = try ctx.paymentMethodRepo.findByName(pName) else {
                throw ToolError.notFound("Payment method '\(pName)'")
            }
            tx.paymentMethod = pm
        }
        try ctx.transactionRepo.update(tx)
        return TxEncoder.encode(tx)
    }
}

struct DeleteTransactionTool: Tool {
    let name = "delete_transaction"
    let description = "Delete a transaction by id."
    let kind: ToolKind = .delete
    var parameters: JSONValue {
        JSONSchemaBuilder.object(
            properties: [
                "id": JSONSchemaBuilder.string("Transaction UUID")
            ],
            required: ["id"]
        )
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        guard let id = ToolArgs.uuid(args, "id") else {
            throw ToolError.invalidArgument("id", reason: "must be UUID")
        }
        try ctx.transactionRepo.delete(id: id)
        return .object(["deleted": .bool(true), "id": .string(id.uuidString)])
    }
}

struct ListTransactionsTool: Tool {
    let name = "list_transactions"
    let description = "List transactions with optional filters. Returns up to 'limit' transactions sorted by date descending."
    let kind: ToolKind = .read
    var parameters: JSONValue {
        JSONSchemaBuilder.object(
            properties: [
                "date_from": JSONSchemaBuilder.string("ISO-8601 lower bound"),
                "date_to": JSONSchemaBuilder.string("ISO-8601 upper bound"),
                "type": JSONSchemaBuilder.string("Filter type", enumValues: ["expense", "income"]),
                "category": JSONSchemaBuilder.string("Category name"),
                "payment_method": JSONSchemaBuilder.string("Payment method name"),
                "limit": JSONSchemaBuilder.integer("Max results (default 50)")
            ]
        )
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        var q = TransactionQuery()
        q.dateFrom = ToolArgs.date(args, "date_from")
        q.dateTo = ToolArgs.date(args, "date_to")
        if let s = ToolArgs.string(args, "type"), let t = TxType(rawValue: s) { q.type = t }
        if let catName = ToolArgs.string(args, "category"),
           let cat = try ctx.categoryRepo.findByName(catName) {
            q.categoryIds = [cat.id]
        }
        if let pmName = ToolArgs.string(args, "payment_method"),
           let pm = try ctx.paymentMethodRepo.findByName(pmName) {
            q.paymentMethodIds = [pm.id]
        }
        q.limit = ToolArgs.int(args, "limit") ?? 50
        q.sortBy = .dateDescending
        let txs = try ctx.transactionRepo.fetch(q)
        return .object([
            "count": .number(Double(txs.count)),
            "transactions": .array(txs.map(TxEncoder.encode))
        ])
    }
}

struct SearchTransactionsTool: Tool {
    let name = "search_transactions"
    let description = "Full-text search over transaction notes, category names, and payment method names."
    let kind: ToolKind = .read
    var parameters: JSONValue {
        JSONSchemaBuilder.object(
            properties: [
                "query": JSONSchemaBuilder.string("Search text"),
                "date_from": JSONSchemaBuilder.string("ISO-8601 lower bound"),
                "date_to": JSONSchemaBuilder.string("ISO-8601 upper bound"),
                "limit": JSONSchemaBuilder.integer("Max results (default 50)")
            ],
            required: ["query"]
        )
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        guard let query = ToolArgs.string(args, "query"), !query.isEmpty else {
            throw ToolError.missingArgument("query")
        }
        var q = TransactionQuery()
        q.textQuery = query
        q.dateFrom = ToolArgs.date(args, "date_from")
        q.dateTo = ToolArgs.date(args, "date_to")
        q.limit = ToolArgs.int(args, "limit") ?? 50
        q.sortBy = .dateDescending
        let txs = try ctx.transactionRepo.fetch(q)
        return .object([
            "count": .number(Double(txs.count)),
            "transactions": .array(txs.map(TxEncoder.encode))
        ])
    }
}
