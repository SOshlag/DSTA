import XCTest
@testable import DadStockAlerts

final class AlertCSVExporterTests: XCTestCase {
    func testExportIncludesTrackingFieldsAndEscapesMultilineNotes() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let tradeTime = Date(timeIntervalSince1970: 1_700_000_100)
        let alert = StockAlert(
            symbol: "AAPL",
            alertType: .buyBelow,
            targetPrice: Decimal(string: "185.50")!,
            lastTradePrice: Decimal(string: "189.24")!,
            lastTradeTimestamp: tradeTime,
            dateCreated: created,
            status: .active,
            marketDataFeed: "IEX Real-Time Trades",
            note: "Support, then \"bounce\"\nReview tomorrow"
        )

        let csv = AlertCSVExporter.csv(for: [alert])

        XCTAssertTrue(csv.hasPrefix("Symbol,Alert Type,Target Price,Last Trade,Status,Note"))
        XCTAssertTrue(csv.contains("AAPL,Buy Below,185.5,189.24,Monitoring"))
        XCTAssertTrue(csv.contains("\"Support, then \"\"bounce\"\"\nReview tomorrow\""))
        XCTAssertTrue(csv.contains("IEX Real-Time Trades"))
    }

    func testExportNeverContainsCredentialFields() {
        let csv = AlertCSVExporter.csv(for: [StockAlert(symbol: "MSFT", alertType: .sellAbove, targetPrice: 500)])

        XCTAssertFalse(csv.localizedCaseInsensitiveContains("api key"))
        XCTAssertFalse(csv.localizedCaseInsensitiveContains("secret"))
        XCTAssertEqual(AlertCSVExporter.data(for: []).prefix(3), Data([0xEF, 0xBB, 0xBF]))
    }
}
