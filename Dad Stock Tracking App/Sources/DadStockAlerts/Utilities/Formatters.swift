import Foundation

enum AppFormatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    static func money(_ value: Decimal) -> String { currency.string(from: value as NSDecimalNumber) ?? "$--" }
}
