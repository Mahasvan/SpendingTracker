import Foundation
import SwiftData

enum DefaultDataSeeder {
    static func seedIfNeeded(in context: ModelContext) {
        seedCategoriesIfNeeded(in: context)
        seedPaymentMethodsIfNeeded(in: context)
    }

    private static func seedCategoriesIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }
        let defaults: [(String, String, String)] = [
            ("Food", "#E57373", "fork.knife"),
            ("Groceries", "#81C784", "cart"),
            ("Transport", "#64B5F6", "car.fill"),
            ("Rent", "#9575CD", "house.fill"),
            ("Utilities", "#FFB74D", "bolt.fill"),
            ("Entertainment", "#F06292", "film"),
            ("Shopping", "#4FC3F7", "bag"),
            ("Health", "#4DB6AC", "cross.case"),
            ("Salary", "#AED581", "indianrupeesign.circle"),
            ("Other", "#90A4AE", "tag")
        ]
        for (name, color, icon) in defaults {
            context.insert(Category(name: name, colorHex: color, systemImage: icon))
        }
        try? context.save()
    }

    private static func seedPaymentMethodsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<PaymentMethod>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }
        let defaults: [(String, PMKind)] = [
            ("Cash", .cash),
            ("Credit Card", .card),
            ("Debit Card", .card),
            ("UPI", .upi),
            ("Bank Transfer", .bankTransfer)
        ]
        for (name, kind) in defaults {
            context.insert(PaymentMethod(name: name, kind: kind))
        }
        try? context.save()
    }
}
