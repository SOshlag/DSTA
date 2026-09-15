import XCTest
@testable import DadStockAlerts

@MainActor
final class TradeProcessingTests: XCTestCase {
    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
    }

    func testTradesWithoutTradeIDsAreStillProcessed() {
        let marketData = MockMarketDataService()
        let model = AppViewModel(store: AlertStore(fileURL: makeTempURL()), marketData: marketData)
        XCTAssertNil(model.add(symbol: "AAPL", type: .sellAbove, targetText: "200"))

        marketData.sendCompletedTrade(symbol: "AAPL", price: 190, timestamp: Date(timeIntervalSince1970: 100), tradeID: nil)
        XCTAssertEqual(model.store.alerts[0].lastTradePrice, 190)

        marketData.sendCompletedTrade(symbol: "AAPL", price: 210, timestamp: Date(timeIntervalSince1970: 200), tradeID: nil)
        XCTAssertEqual(model.store.alerts[0].lastTradePrice, 210)
        XCTAssertEqual(model.store.alerts[0].status, .triggered)
    }

    func testDuplicateTradeIDIsIgnored() {
        let marketData = MockMarketDataService()
        let model = AppViewModel(store: AlertStore(fileURL: makeTempURL()), marketData: marketData)
        XCTAssertNil(model.add(symbol: "AAPL", type: .sellAbove, targetText: "200"))

        marketData.sendCompletedTrade(symbol: "AAPL", price: 190, timestamp: Date(timeIntervalSince1970: 100), tradeID: "same")
        marketData.sendCompletedTrade(symbol: "AAPL", price: 210, timestamp: Date(timeIntervalSince1970: 200), tradeID: "same")

        XCTAssertEqual(model.store.alerts[0].lastTradePrice, 190)
        XCTAssertEqual(model.store.alerts[0].status, .active)
    }

    func testCoalescedReplaceBatchesDiskWritesUntilFlushed() {
        let url = makeTempURL()
        let store = AlertStore(fileURL: url)
        store.add(StockAlert(symbol: "AAPL", alertType: .buyBelow, targetPrice: 185))

        var updated = store.alerts[0]
        updated.lastTradePrice = 190
        store.replace(updated, coalescingSave: true)

        XCTAssertNil(AlertStore(fileURL: url).alerts.first?.lastTradePrice, "Coalesced replace should not write to disk immediately")

        store.flushPendingSave()
        XCTAssertEqual(AlertStore(fileURL: url).alerts.first?.lastTradePrice, 190)
    }

    func testImmediateReplaceStillWritesToDisk() {
        let url = makeTempURL()
        let store = AlertStore(fileURL: url)
        store.add(StockAlert(symbol: "AAPL", alertType: .buyBelow, targetPrice: 185))

        var updated = store.alerts[0]
        updated.status = .paused
        store.replace(updated)

        XCTAssertEqual(AlertStore(fileURL: url).alerts.first?.status, .paused)
    }
}
