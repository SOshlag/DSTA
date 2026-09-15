import Foundation

enum AlertCSVExporter {
    static let headers = [
        "Symbol",
        "Alert Type",
        "Target Price",
        "Last Trade",
        "Status",
        "Note",
        "Created",
        "Last Trade Time",
        "Triggered Time",
        "Market Data Feed",
    ]

    static func csv(for alerts: [StockAlert]) -> String {
        let rows = alerts
            .sorted { $0.dateCreated < $1.dateCreated }
            .map { alert in
                [
                    alert.symbol,
                    alert.alertType.title,
                    decimal(alert.targetPrice),
                    alert.lastTradePrice.map(decimal) ?? "",
                    alert.status.title,
                    alert.note ?? "",
                    date(alert.dateCreated),
                    alert.lastTradeTimestamp.map(date) ?? "",
                    alert.dateTriggered.map(date) ?? "",
                    alert.marketDataFeed,
                ]
                .map(escape)
                .joined(separator: ",")
            }

        return ([headers.map(escape).joined(separator: ",")] + rows).joined(separator: "\r\n") + "\r\n"
    }

    static func data(for alerts: [StockAlert]) -> Data {
        var data = Data([0xEF, 0xBB, 0xBF]) // UTF-8 BOM helps Excel preserve punctuation and notes.
        data.append(Data(csv(for: alerts).utf8))
        return data
    }

    private static func decimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func date(_ value: Date) -> String {
        formatter.string(from: value)
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
