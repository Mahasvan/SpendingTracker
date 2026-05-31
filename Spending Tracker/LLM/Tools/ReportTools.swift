import Foundation

struct GetSummaryTool: Tool {
    let name = "get_summary"
    let description = "Aggregate totals for a period. Supports grouping by category, payment_method, type, or day."
    let kind: ToolKind = .read
    var parameters: JSONValue {
        JSONSchemaBuilder.object(
            properties: [
                "period": JSONSchemaBuilder.string(
                    "Period (this_month, last_month, last_30_days, all). If using 'custom', provide date_from/date_to.",
                    enumValues: ["this_month", "last_month", "last_30_days", "all", "custom"]
                ),
                "date_from": JSONSchemaBuilder.string("ISO-8601 lower bound (for 'custom')"),
                "date_to": JSONSchemaBuilder.string("ISO-8601 upper bound (for 'custom')"),
                "group_by": JSONSchemaBuilder.string(
                    "Optional grouping",
                    enumValues: ["category", "payment_method", "type", "day"]
                )
            ],
            required: ["period"]
        )
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        let periodStr = ToolArgs.string(args, "period") ?? "this_month"
        let range: DateRange
        switch periodStr {
        case "this_month": range = .thisMonth
        case "last_month": range = .lastMonth
        case "last_30_days": range = .last30Days
        case "all": range = .allTime
        case "custom":
            let from = ToolArgs.date(args, "date_from") ?? Date(timeIntervalSince1970: 0)
            let to = ToolArgs.date(args, "date_to") ?? .now
            range = DateRange(start: from, end: to)
        default: range = .thisMonth
        }

        var q = TransactionQuery()
        q.dateFrom = range.start
        q.dateTo = range.end
        let txs = try ctx.transactionRepo.fetch(q)
        var totalExpense: Decimal = 0
        var totalIncome: Decimal = 0
        for tx in txs {
            switch tx.type {
            case .expense: totalExpense += tx.amount
            case .income: totalIncome += tx.amount
            }
        }
        var out: [String: JSONValue] = [
            "period": .string(periodStr),
            "from": .string(ISO8601DateFormatter.shared.string(from: range.start)),
            "to": .string(ISO8601DateFormatter.shared.string(from: range.end)),
            "total_expense": .number(NSDecimalNumber(decimal: totalExpense).doubleValue),
            "total_income": .number(NSDecimalNumber(decimal: totalIncome).doubleValue),
            "net": .number(NSDecimalNumber(decimal: totalIncome - totalExpense).doubleValue),
            "count": .number(Double(txs.count))
        ]

        if let gb = ToolArgs.string(args, "group_by") {
            out["groups"] = groupBy(txs, key: gb)
            out["group_by"] = .string(gb)
        }
        return .object(out)
    }

    private func groupBy(_ txs: [Transaction], key: String) -> JSONValue {
        var buckets: [String: (expense: Decimal, income: Decimal, count: Int)] = [:]
        for tx in txs {
            let k: String
            switch key {
            case "category": k = tx.category?.name ?? "(uncategorized)"
            case "payment_method": k = tx.paymentMethod?.name ?? "(none)"
            case "type": k = tx.type.rawValue
            case "day":
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = "yyyy-MM-dd"
                k = df.string(from: tx.date)
            default: k = "all"
            }
            var entry = buckets[k] ?? (0, 0, 0)
            switch tx.type {
            case .expense: entry.expense += tx.amount
            case .income: entry.income += tx.amount
            }
            entry.count += 1
            buckets[k] = entry
        }
        let arr: [JSONValue] = buckets
            .map { (k, v) in
                .object([
                    "key": .string(k),
                    "expense": .number(NSDecimalNumber(decimal: v.expense).doubleValue),
                    "income": .number(NSDecimalNumber(decimal: v.income).doubleValue),
                    "count": .number(Double(v.count))
                ])
            }
            .sorted { a, b in
                (a["expense"]?.numberValue ?? 0) > (b["expense"]?.numberValue ?? 0)
            }
        return .array(arr)
    }
}

struct GetBudgetStatusTool: Tool {
    let name = "get_budget_status"
    let description = "Returns budget usage per category for the current month."
    let kind: ToolKind = .read
    var parameters: JSONValue {
        JSONSchemaBuilder.object(properties: [:])
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        let budgets = try ctx.budgetRepo.all()
        let range = DateRange.thisMonth
        var q = TransactionQuery()
        q.dateFrom = range.start
        q.dateTo = range.end
        q.type = .expense
        let txs = try ctx.transactionRepo.fetch(q)

        var spentByCat: [UUID: Decimal] = [:]
        for tx in txs {
            guard let cid = tx.category?.id else { continue }
            spentByCat[cid, default: 0] += tx.amount
        }
        let items: [JSONValue] = budgets.compactMap { b in
            guard let cat = b.category else { return nil }
            let spent = spentByCat[cat.id] ?? 0
            let limit = b.amount
            let pct: Double = limit > 0
                ? NSDecimalNumber(decimal: spent).doubleValue / NSDecimalNumber(decimal: limit).doubleValue
                : 0
            return .object([
                "category": .string(cat.name),
                "limit": .number(NSDecimalNumber(decimal: limit).doubleValue),
                "spent": .number(NSDecimalNumber(decimal: spent).doubleValue),
                "remaining": .number(NSDecimalNumber(decimal: limit - spent).doubleValue),
                "percent": .number(pct)
            ])
        }
        return .object([
            "period": .string("this_month"),
            "items": .array(items)
        ])
    }
}
