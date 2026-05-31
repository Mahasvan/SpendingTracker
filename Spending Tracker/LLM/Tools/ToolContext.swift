import Foundation

@MainActor
final class ToolContext {
    let transactionRepo: any TransactionRepository
    let categoryRepo: any CategoryRepository
    let paymentMethodRepo: any PaymentMethodRepository
    let budgetRepo: any BudgetRepository

    init(
        transactionRepo: any TransactionRepository,
        categoryRepo: any CategoryRepository,
        paymentMethodRepo: any PaymentMethodRepository,
        budgetRepo: any BudgetRepository
    ) {
        self.transactionRepo = transactionRepo
        self.categoryRepo = categoryRepo
        self.paymentMethodRepo = paymentMethodRepo
        self.budgetRepo = budgetRepo
    }
}

enum JSONSchemaBuilder {
    static func object(properties: [String: JSONValue], required: [String] = []) -> JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array(required.map { .string($0) })
        ])
    }
    static func string(_ description: String, enumValues: [String]? = nil) -> JSONValue {
        var d: [String: JSONValue] = [
            "type": .string("string"),
            "description": .string(description)
        ]
        if let enumValues {
            d["enum"] = .array(enumValues.map { .string($0) })
        }
        return .object(d)
    }
    static func number(_ description: String) -> JSONValue {
        .object([
            "type": .string("number"),
            "description": .string(description)
        ])
    }
    static func integer(_ description: String) -> JSONValue {
        .object([
            "type": .string("integer"),
            "description": .string(description)
        ])
    }
    static func boolean(_ description: String) -> JSONValue {
        .object([
            "type": .string("boolean"),
            "description": .string(description)
        ])
    }
    static func array(of items: JSONValue, description: String) -> JSONValue {
        .object([
            "type": .string("array"),
            "items": items,
            "description": .string(description)
        ])
    }
}

enum ToolArgs {
    static func string(_ args: JSONValue, _ key: String) -> String? { args[key]?.stringValue }
    static func required(_ args: JSONValue, _ key: String) throws -> JSONValue {
        guard let v = args[key] else { throw ToolError.missingArgument(key) }
        return v
    }
    static func decimal(_ args: JSONValue, _ key: String) -> Decimal? {
        if let n = args[key]?.numberValue { return Decimal(n) }
        if let s = args[key]?.stringValue { return Decimal(string: s) }
        return nil
    }
    static func uuid(_ args: JSONValue, _ key: String) -> UUID? {
        guard let s = args[key]?.stringValue else { return nil }
        return UUID(uuidString: s)
    }
    static func date(_ args: JSONValue, _ key: String) -> Date? {
        guard let s = args[key]?.stringValue else { return nil }
        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFull.date(from: s) { return d }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
    static func int(_ args: JSONValue, _ key: String) -> Int? {
        if let n = args[key]?.numberValue { return Int(n) }
        if let s = args[key]?.stringValue { return Int(s) }
        return nil
    }
}

enum TxEncoder {
    static func encode(_ tx: Transaction) -> JSONValue {
        .object([
            "id": .string(tx.id.uuidString),
            "amount": .number(NSDecimalNumber(decimal: tx.amount).doubleValue),
            "type": .string(tx.type.rawValue),
            "date": .string(ISO8601DateFormatter.shared.string(from: tx.date)),
            "note": .string(tx.note),
            "category": tx.category.map { .string($0.name) } ?? .null,
            "category_id": tx.category.map { .string($0.id.uuidString) } ?? .null,
            "payment_method": tx.paymentMethod.map { .string($0.name) } ?? .null,
            "payment_method_id": tx.paymentMethod.map { .string($0.id.uuidString) } ?? .null
        ])
    }
}

extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
