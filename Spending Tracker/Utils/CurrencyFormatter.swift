import Foundation

enum CurrencyFormatter {
    static let inrLocale = Locale(identifier: "en_IN")

    static func format(_ amount: Decimal, withSymbol: Bool = true) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = withSymbol ? .currency : .decimal
        nf.currencyCode = "INR"
        nf.locale = inrLocale
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 2
        return nf.string(from: amount as NSDecimalNumber) ?? "₹0.00"
    }

    static func formatSigned(_ amount: Decimal, type: TxType) -> String {
        let prefix = type == .income ? "+" : "−"
        return "\(prefix)\(format(amount))"
    }

    static func parse(_ s: String) -> Decimal? {
        let cleaned = s
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned)
    }

    static func editString(_ amount: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = false
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 0
        return nf.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
