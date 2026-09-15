import XCTest
@testable import DadStockAlerts

@MainActor
final class PrimaryAlertTests: XCTestCase {
    private func makeModel() -> AppViewModel {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        return AppViewModel(store: AlertStore(fileURL: url), marketData: MockMarketDataService())
    }

    func testPrimaryAlertIsNewestWhenNothingIsTriggered() {
        let model = makeModel()
        XCTAssertNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "185"))
        XCTAssertNil(model.add(symbol: "MSFT", type: .buyBelow, targetText: "400"))
        XCTAssertEqual(model.primaryAlert?.symbol, "MSFT")
    }

    func testTriggeredAlertTakesPriorityOverNewerAlert() {
        let model = makeModel()
        let marketData = model.marketData as! MockMarketDataService
        XCTAssertNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "185"))
        XCTAssertNil(model.add(symbol: "MSFT", type: .buyBelow, targetText: "400"))

        marketData.sendCompletedTrade(symbol: "AAPL", price: 180)

        XCTAssertEqual(model.store.alerts.first(where: { $0.symbol == "AAPL" })?.status, .triggered)
        XCTAssertEqual(model.primaryAlert?.symbol, "AAPL")
    }

    func testMostRecentlyTriggeredAlertWins() {
        let model = makeModel()
        let marketData = model.marketData as! MockMarketDataService
        XCTAssertNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "185"))
        XCTAssertNil(model.add(symbol: "MSFT", type: .sellAbove, targetText: "400"))

        marketData.sendCompletedTrade(symbol: "MSFT", price: 410)
        marketData.sendCompletedTrade(symbol: "AAPL", price: 180)

        XCTAssertEqual(model.primaryAlert?.symbol, "AAPL")
    }
}
