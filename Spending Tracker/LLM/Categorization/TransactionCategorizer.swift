import Foundation
import FoundationModels

/// On-device categorization of transactions using Apple's Foundation Models.
///
/// `@Generable` is used to parse the model's batch response into structured
/// `CategorizedBatch` instances. The allowed category names cannot be expressed
/// as a schema-level `anyOf` constraint because the live category list is runtime
/// data (per-user, mutable in SwiftData) and `@Guide` is evaluated at the
/// property declaration — so the allowed list is injected into the per-batch
/// prompt instead, and the apply step validates every emitted name against the
/// real categories before writing. No invalid category can ever be persisted.
@available(macOS 26.0, iOS 26.0, *)
@Generable
struct CategorizedBatch {
    @Guide(description: "One entry per input transaction, in any order.", .maximumCount(64))
    var items: [Item]

    @Generable
    struct Item {
        @Guide(description: "The transaction UUID exactly as provided in the input.")
        var transactionId: String
        @Guide(description: "Best-matching category name from the list in the prompt. Use the last-resort category if none fit.")
        var category: String
    }
}

/// Runs the on-device model over transactions in small, fresh-session batches and
/// applies the resulting categories via the caller-supplied `apply` closure.
///
/// Batching is required because the SystemLanguageModel has a small context
/// window: each batch gets its own short-lived `LanguageModelSession` so context
/// never accumulates across batches, and on `contextSizeExceeded` the batch is
/// halved and retried until it fits (or a single transaction is skipped).
@available(macOS 26.0, iOS 26.0, *)
@MainActor
struct TransactionCategorizer {
    /// Default transactions per model call. Keeps prompt + generated batch well
    /// under the on-device context window for typical short notes.
    nonisolated static let defaultChunkSize = 15

    struct Summary: Sendable {
        var processed: Int = 0
        var categorized: Int = 0
        var skipped: Int = 0
        var batches: Int = 0
        var samples: [(id: UUID, note: String, category: String)] = []
    }

    /// Categorizes the given transactions, calling `apply(uuid, categoryName)`
    /// for each successful assignment. `categories` must be the non-archived
    /// category names available for assignment; `lastResort` (e.g. "Other") is
    /// used when the model emits a name not in `categories`.
    func categorize(
        _ txs: [Transaction],
        categories: [String],
        lastResort: String?,
        chunkSize: Int = Self.defaultChunkSize,
        apply: (UUID, String) throws -> Void
    ) async throws -> Summary {
        guard !txs.isEmpty else { return Summary() }
        let allowedLower = Set(categories.map { $0.lowercased() })
        let lastResortLower = lastResort?.lowercased()

        var summary = Summary()
        var size = max(1, chunkSize)

        var index = 0
        while index < txs.count {
            let end = min(index + size, txs.count)
            let batch = Array(txs[index..<end])

            do {
                let items = try await runBatch(batch, categories: categories)
                summary.batches += 1
                summary.processed += batch.count

                // Dictionary(uniqueKeysWithValues:) traps on duplicate keys, which
                // the model can produce (hallucinated repeated transactionIds).
                // uniquingKeysWith: keeps the last entry per id — fine since any
                // duplicate is garbage and will be validated/filtered below.
                let byId = Dictionary(items.compactMap {
                    if let uuid = UUID(uuidString: $0.transactionId) { return (uuid, $0) } else { return nil }
                }, uniquingKeysWith: { _, last in last })

                for tx in batch {
                    guard let item = byId[tx.id] else {
                        summary.skipped += 1
                        continue
                    }
                    let resolved = resolveCategory(item.category, allowedLower: allowedLower, lastResortLower: lastResortLower)
                    guard let resolved else {
                        summary.skipped += 1
                        continue
                    }
                    do {
                        try apply(tx.id, resolved)
                        summary.categorized += 1
                        if summary.samples.count < 10 {
                            summary.samples.append((tx.id, tx.note, resolved))
                        }
                    } catch {
                        summary.skipped += 1
                    }
                }

                index = end
                // Restore chunk size after a successful (possibly retried) batch
                // so a single long-note batch doesn't permanently shrink throughput.
                size = max(1, chunkSize)
            } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                if batch.count <= 1 {
                    // A single transaction still overflows — skip it and move on.
                    summary.skipped += 1
                    summary.processed += 1
                    index += 1
                    size = max(1, chunkSize)
                } else {
                    size = max(1, batch.count / 2)
                }
            }
        }

        return summary
    }

    /// Runs one batch through a fresh session and returns the parsed items.
    private func runBatch(_ batch: [Transaction], categories: [String]) async throws -> [CategorizedBatch.Item] {
        let session = LanguageModelSession(instructions: """
        You categorize personal spending transactions. For each transaction, pick the \
        single best category from the provided list. Output exactly one entry per \
        transaction, reusing the transaction's UUID verbatim. If no category fits, \
        use the last-resort category named in the prompt.
        """)

        let prompt = buildPrompt(batch, categories: categories)
        let response = try await session.respond(to: prompt, generating: CategorizedBatch.self)
        return response.content.items
    }

    private func buildPrompt(_ batch: [Transaction], categories: [String]) -> String {
        var lines = ["Categories (use exactly one of these names):"]
        lines.append(categories.joined(separator: ", "))
        if let last = categories.last {
            lines.append("If none fit, use: \(last)")
        }
        lines.append("")
        lines.append("Transactions to categorize:")
        for tx in batch {
            let note = tx.note.isEmpty ? "(no note)" : tx.note
            // ponytail: amount/type only — date and payment method don't help category choice
            // and every extra field grows the prompt toward the context ceiling.
            lines.append("- id=\(tx.id.uuidString) | \(tx.type.rawValue) | \(formattedAmount(tx)) | \(note)")
        }
        return lines.joined(separator: "\n")
    }

    private func formattedAmount(_ tx: Transaction) -> String {
        let n = NSDecimalNumber(decimal: tx.amount)
        return "\(n.doubleValue)"
    }

    /// Maps an emitted category name to a real one. Case-insensitive; falls back
    /// to the last-resort category only if the emitted name matches it. Returns
    /// nil for anything else (counted as skipped by the caller).
    private func resolveCategory(
        _ emitted: String,
        allowedLower: Set<String>,
        lastResortLower: String?
    ) -> String? {
        let lower = emitted.trimmingCharacters(in: .whitespaces).lowercased()
        if allowedLower.contains(lower) {
            return emitted.trimmingCharacters(in: .whitespaces)
        }
        if let lastResortLower, lower == lastResortLower {
            return emitted.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    // MARK: - Pure helpers (testable without the model)

    /// Splits transactions into chunks of `size`. Exposed for unit testing.
    static func chunk(_ txs: [Transaction], size: Int) -> [[Transaction]] {
        guard size > 0, !txs.isEmpty else { return txs.isEmpty ? [] : [txs] }
        return stride(from: 0, to: txs.count, by: size).map {
            Array(txs[$0..<min($0 + size, txs.count)])
        }
    }
}
