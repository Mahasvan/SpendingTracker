import Foundation
import SwiftData

enum ImportExportError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case decode(String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v): return "Unsupported backup version: \(v)"
        case .decode(let s): return "Decode failed: \(s)"
        case .underlying(let e): return e.localizedDescription
        }
    }
}

@MainActor
final class ImportExportService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Export

    func exportAll(includeChatHistory: Bool = true) throws -> Data {
        let cats = try context.fetch(FetchDescriptor<Category>())
        let pms = try context.fetch(FetchDescriptor<PaymentMethod>())
        let txs = try context.fetch(FetchDescriptor<Transaction>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())

        var chatSessions: [BackupChatSession]? = nil
        if includeChatHistory {
            let sessions = try context.fetch(FetchDescriptor<ChatSession>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            ))
            chatSessions = sessions.map { s in
                let msgs = (s.messages ?? [])
                    .sorted { $0.createdAt < $1.createdAt }
                    .map { BackupChatMessage(
                        id: $0.id, role: $0.role.rawValue, content: $0.content,
                        toolCallsJSON: $0.toolCallsJSON, toolName: $0.toolName,
                        toolCallId: $0.toolCallId, createdAt: $0.createdAt
                    ) }
                return BackupChatSession(
                    id: s.id, title: s.title,
                    createdAt: s.createdAt, updatedAt: s.updatedAt,
                    messages: msgs
                )
            }
        }

        let backup = BackupFile(
            version: BackupFile.currentVersion,
            exportedAt: .now,
            categories: cats.map { c in
                BackupCategory(
                    id: c.id, name: c.name, colorHex: c.colorHex,
                    systemImage: c.systemImage, archived: c.archived,
                    createdAt: c.createdAt
                )
            },
            paymentMethods: pms.map { pm in
                BackupPaymentMethod(
                    id: pm.id, name: pm.name, kind: pm.kindRaw,
                    archived: pm.archived, createdAt: pm.createdAt
                )
            },
            transactions: txs.map { tx in
                BackupTransaction(
                    id: tx.id, amount: tx.amount, type: tx.typeRaw,
                    date: tx.date, note: tx.note,
                    categoryId: tx.category?.id,
                    paymentMethodId: tx.paymentMethod?.id,
                    createdAt: tx.createdAt, updatedAt: tx.updatedAt
                )
            },
            budgets: budgets.map { b in
                BackupBudget(
                    id: b.id, amount: b.amount, period: b.periodRaw,
                    startDate: b.startDate, categoryId: b.category?.id,
                    createdAt: b.createdAt
                )
            },
            chatSessions: chatSessions
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    // MARK: - Import

    func importBackup(_ data: Data, mode: ImportMode) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: BackupFile
        do { backup = try decoder.decode(BackupFile.self, from: data) }
        catch { throw ImportExportError.decode(error.localizedDescription) }
        guard backup.version == BackupFile.currentVersion else {
            throw ImportExportError.unsupportedVersion(backup.version)
        }

        var summary = ImportSummary()

        if mode == .replace {
            summary.deletedBeforeReplace = try wipeAll()
        }

        // Dedup rules:
        // - Categories / PaymentMethods: match by UUID first, then by name (case-insensitive trimmed).
        //   When matched by name with a different UUID, we map the imported UUID to the existing entity
        //   so referencing transactions/budgets stay consistent. No new row is created.
        // - Transactions / Budgets / ChatSessions: UUID only (no natural key).

        var categoryIdRemap: [UUID: UUID] = [:]
        var categoriesByRealId: [UUID: Category] = [:]
        for entry in backup.categories {
            if let byId = try findCategory(id: entry.id) {
                byId.name = entry.name
                byId.colorHex = entry.colorHex
                byId.systemImage = entry.systemImage
                byId.archived = entry.archived
                categoriesByRealId[byId.id] = byId
                categoryIdRemap[entry.id] = byId.id
            } else if let byName = try findCategory(byNormalizedName: entry.name) {
                byName.colorHex = entry.colorHex
                byName.systemImage = entry.systemImage
                byName.archived = entry.archived
                categoriesByRealId[byName.id] = byName
                categoryIdRemap[entry.id] = byName.id
            } else {
                let c = Category(
                    id: entry.id, name: entry.name, colorHex: entry.colorHex,
                    systemImage: entry.systemImage, archived: entry.archived,
                    createdAt: entry.createdAt
                )
                context.insert(c)
                categoriesByRealId[c.id] = c
                categoryIdRemap[entry.id] = c.id
            }
            summary.categoriesUpserted += 1
        }

        var pmIdRemap: [UUID: UUID] = [:]
        var pmsByRealId: [UUID: PaymentMethod] = [:]
        for entry in backup.paymentMethods {
            let kind = PMKind(rawValue: entry.kind) ?? .other
            if let byId = try findPaymentMethod(id: entry.id) {
                byId.name = entry.name
                byId.kindRaw = entry.kind
                byId.archived = entry.archived
                pmsByRealId[byId.id] = byId
                pmIdRemap[entry.id] = byId.id
            } else if let byName = try findPaymentMethod(byNormalizedName: entry.name) {
                byName.kindRaw = entry.kind
                byName.archived = entry.archived
                pmsByRealId[byName.id] = byName
                pmIdRemap[entry.id] = byName.id
            } else {
                let pm = PaymentMethod(
                    id: entry.id, name: entry.name, kind: kind,
                    archived: entry.archived, createdAt: entry.createdAt
                )
                context.insert(pm)
                pmsByRealId[pm.id] = pm
                pmIdRemap[entry.id] = pm.id
            }
            summary.paymentMethodsUpserted += 1
        }

        func resolveCategory(_ incoming: UUID?) throws -> Category? {
            guard let incoming else { return nil }
            if let realId = categoryIdRemap[incoming], let c = categoriesByRealId[realId] { return c }
            if let c = try findCategory(id: incoming) { return c }
            return nil
        }
        func resolvePM(_ incoming: UUID?) throws -> PaymentMethod? {
            guard let incoming else { return nil }
            if let realId = pmIdRemap[incoming], let pm = pmsByRealId[realId] { return pm }
            if let pm = try findPaymentMethod(id: incoming) { return pm }
            return nil
        }

        for entry in backup.budgets {
            let cat = try resolveCategory(entry.categoryId)
            // If a budget already exists for this category+period, treat it as a duplicate
            // even if the UUIDs differ — we don't want two monthly budgets per category.
            if let e = try findBudget(id: entry.id) {
                e.amount = entry.amount
                e.periodRaw = entry.period
                e.startDate = entry.startDate
                e.category = cat
            } else if let cat,
                      let dup = try findBudget(forCategory: cat.id, periodRaw: entry.period) {
                dup.amount = entry.amount
                dup.startDate = entry.startDate
            } else {
                let b = Budget(
                    id: entry.id, amount: entry.amount,
                    period: BudgetPeriod(rawValue: entry.period) ?? .monthly,
                    startDate: entry.startDate, category: cat,
                    createdAt: entry.createdAt
                )
                context.insert(b)
            }
            summary.budgetsUpserted += 1
        }

        for entry in backup.transactions {
            let existing = try findTransaction(id: entry.id)
            let cat = try resolveCategory(entry.categoryId)
            let pm = try resolvePM(entry.paymentMethodId)
            let type = TxType(rawValue: entry.type) ?? .expense
            if let e = existing {
                e.amount = entry.amount
                e.typeRaw = entry.type
                e.date = entry.date
                e.note = entry.note
                e.category = cat
                e.paymentMethod = pm
                e.updatedAt = entry.updatedAt
            } else {
                let tx = Transaction(
                    id: entry.id, amount: entry.amount, type: type,
                    date: entry.date, note: entry.note,
                    category: cat, paymentMethod: pm,
                    createdAt: entry.createdAt, updatedAt: entry.updatedAt
                )
                context.insert(tx)
            }
            summary.transactionsUpserted += 1
        }

        if let sessions = backup.chatSessions {
            for s in sessions {
                let existing = try findChatSession(id: s.id)
                let session: ChatSession
                if let e = existing {
                    e.title = s.title
                    e.updatedAt = s.updatedAt
                    session = e
                } else {
                    session = ChatSession(
                        id: s.id, title: s.title,
                        createdAt: s.createdAt, updatedAt: s.updatedAt
                    )
                    context.insert(session)
                }
                let existingMsgIds = Set((session.messages ?? []).map(\.id))
                for m in s.messages where !existingMsgIds.contains(m.id) {
                    let role = ChatRole(rawValue: m.role) ?? .user
                    let msg = ChatMessage(
                        id: m.id, role: role, content: m.content,
                        toolCallsJSON: m.toolCallsJSON, toolName: m.toolName,
                        toolCallId: m.toolCallId, session: session,
                        createdAt: m.createdAt
                    )
                    context.insert(msg)
                }
                summary.chatSessionsUpserted += 1
            }
        }

        try context.save()
        return summary
    }

    // MARK: - Helpers

    private func wipeAll() throws -> Int {
        var count = 0
        for tx in try context.fetch(FetchDescriptor<Transaction>()) {
            context.delete(tx); count += 1
        }
        for b in try context.fetch(FetchDescriptor<Budget>()) {
            context.delete(b); count += 1
        }
        for c in try context.fetch(FetchDescriptor<Category>()) {
            context.delete(c); count += 1
        }
        for pm in try context.fetch(FetchDescriptor<PaymentMethod>()) {
            context.delete(pm); count += 1
        }
        for s in try context.fetch(FetchDescriptor<ChatSession>()) {
            context.delete(s); count += 1
        }
        try context.save()
        return count
    }

    private func findCategory(id: UUID) throws -> Category? {
        var d = FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func findCategory(byNormalizedName name: String) throws -> Category? {
        let target = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !target.isEmpty else { return nil }
        let all = try context.fetch(FetchDescriptor<Category>())
        return all.first { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == target }
    }
    private func findPaymentMethod(id: UUID) throws -> PaymentMethod? {
        var d = FetchDescriptor<PaymentMethod>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func findPaymentMethod(byNormalizedName name: String) throws -> PaymentMethod? {
        let target = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !target.isEmpty else { return nil }
        let all = try context.fetch(FetchDescriptor<PaymentMethod>())
        return all.first { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == target }
    }
    private func findBudget(id: UUID) throws -> Budget? {
        var d = FetchDescriptor<Budget>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func findBudget(forCategory categoryId: UUID, periodRaw: String) throws -> Budget? {
        let d = FetchDescriptor<Budget>(predicate: #Predicate { $0.periodRaw == periodRaw })
        return try context.fetch(d).first { $0.category?.id == categoryId }
    }
    private func findTransaction(id: UUID) throws -> Transaction? {
        var d = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func findChatSession(id: UUID) throws -> ChatSession? {
        var d = FetchDescriptor<ChatSession>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }
}
