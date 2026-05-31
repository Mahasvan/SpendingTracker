import Foundation

struct BackupFile: Codable, Sendable {
    var version: Int
    var exportedAt: Date
    var categories: [BackupCategory]
    var paymentMethods: [BackupPaymentMethod]
    var transactions: [BackupTransaction]
    var budgets: [BackupBudget]
    var chatSessions: [BackupChatSession]?

    static let currentVersion = 1
}

struct BackupCategory: Codable, Sendable {
    var id: UUID
    var name: String
    var colorHex: String
    var systemImage: String
    var archived: Bool
    var createdAt: Date
}

struct BackupPaymentMethod: Codable, Sendable {
    var id: UUID
    var name: String
    var kind: String
    var archived: Bool
    var createdAt: Date
}

struct BackupTransaction: Codable, Sendable {
    var id: UUID
    var amount: Decimal
    var type: String
    var date: Date
    var note: String
    var categoryId: UUID?
    var paymentMethodId: UUID?
    var createdAt: Date
    var updatedAt: Date
}

struct BackupBudget: Codable, Sendable {
    var id: UUID
    var amount: Decimal
    var period: String
    var startDate: Date
    var categoryId: UUID?
    var createdAt: Date
}

struct BackupChatSession: Codable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [BackupChatMessage]
}

struct BackupChatMessage: Codable, Sendable {
    var id: UUID
    var role: String
    var content: String
    var toolCallsJSON: String
    var toolName: String
    var toolCallId: String
    var createdAt: Date
}

enum ImportMode: String, CaseIterable, Identifiable, Sendable {
    case merge
    case replace

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .merge: return "Merge (keep existing, upsert by id)"
        case .replace: return "Replace (wipe local first)"
        }
    }
}

struct ImportSummary: Sendable {
    var categoriesUpserted: Int = 0
    var paymentMethodsUpserted: Int = 0
    var transactionsUpserted: Int = 0
    var budgetsUpserted: Int = 0
    var chatSessionsUpserted: Int = 0
    var deletedBeforeReplace: Int = 0
}
