import Foundation

enum TxType: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense
    case income

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        }
    }
}

enum PMKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case cash
    case card
    case upi
    case wallet
    case bankTransfer
    case other

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .card: return "Card"
        case .upi: return "UPI"
        case .wallet: return "Wallet"
        case .bankTransfer: return "Bank Transfer"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .upi: return "qrcode"
        case .wallet: return "wallet.pass"
        case .bankTransfer: return "building.columns"
        case .other: return "questionmark.circle"
        }
    }
}

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable, Sendable {
    case monthly

    var id: String { rawValue }
    var displayName: String { "Monthly" }
}

enum ChatRole: String, Codable, CaseIterable, Sendable {
    case system
    case user
    case assistant
    case tool
}

enum ToolConfirmPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto
    case confirm
    case disabled

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .confirm: return "Confirm"
        case .disabled: return "Disabled"
        }
    }
}

enum ReasoningLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case low
    case medium
    case high

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

enum LLMProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case ollama
    case appleFoundation

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .appleFoundation: return "Apple Intelligence"
        }
    }

    var icon: String {
        switch self {
        case .ollama: return "server.rack"
        case .appleFoundation: return "apple.logo"
        }
    }
}
