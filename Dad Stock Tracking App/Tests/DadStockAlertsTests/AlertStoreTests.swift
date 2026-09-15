import XCTest
@testable import DadStockAlerts

@MainActor
final class AlertStoreTests: XCTestCase {
    func testAlertsPersistAndReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let store = AlertStore(fileURL: url)
        store.add(StockAlert(symbol: "AAPL", alertType: .buyBelow, targetPrice: 185))
        let reloaded = AlertStore(fileURL: url)
        XCTAssertEqual(reloaded.alerts.count, 1)
        XCTAssertEqual(reloaded.alerts.first?.symbol, "AAPL")
    }

    func testViewModelCreatesAlertAndReceivesOnlyCompletedTradeModel() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let store = AlertStore(fileURL: url)
        let marketData = MockMarketDataService()
        let model = AppViewModel(store: store, marketData: marketData)

        XCTAssertNil(model.add(symbol: " aapl ", type: .buyBelow, targetText: "185.00"))
        XCTAssertEqual(store.alerts.first?.symbol, "AAPL")
        XCTAssertEqual(store.alerts.first?.status, .waitingForTrade)

        marketData.sendCompletedTrade(symbol: "AAPL", price: Decimal(string: "184.96")!)

        XCTAssertEqual(store.alerts.first?.lastTradePrice, Decimal(string: "184.96"))
        XCTAssertNotNil(store.alerts.first?.lastTradeTimestamp)
        XCTAssertEqual(store.alerts.first?.status, .triggered)

        let reloaded = AlertStore(fileURL: url)
        XCTAssertEqual(reloaded.alerts.first?.lastTradePrice, Decimal(string: "184.96"))
    }

    func testOlderSnapshotCannotOverwriteNewerLiveTrade() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let marketData = MockMarketDataService()
        let model = AppViewModel(store: AlertStore(fileURL: url), marketData: marketData)
        XCTAssertNil(model.add(symbol: "AAPL", type: .sellAbove, targetText: "200"))
        let newer = Date(timeIntervalSince1970: 200)
        let older = Date(timeIntervalSince1970: 100)

        marketData.sendCompletedTrade(symbol: "AAPL", price: 190, timestamp: newer, tradeID: "newer")
        marketData.sendCompletedTrade(symbol: "AAPL", price: 210, timestamp: older, tradeID: "older")

        XCTAssertEqual(model.store.alerts[0].lastTradePrice, 190)
        XCTAssertEqual(model.store.alerts[0].lastTradeTimestamp, newer)
        XCTAssertEqual(model.store.alerts[0].status, .active)
    }

    func testExactDuplicateIsRejectedButDifferentTargetIsAllowed() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let model = AppViewModel(store: AlertStore(fileURL: url), marketData: MockMarketDataService())

        XCTAssertNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "185"))
        XCTAssertNotNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "185.00"))
        XCTAssertNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "180"))
        XCTAssertNil(model.add(symbol: "AAPL", type: .sellAbove, targetText: "185"))
        XCTAssertEqual(model.store.alerts.count, 3)
    }

    func testBuyBelowAndSellAboveTriggerFromCompletedTrades() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let marketData = MockMarketDataService()
        let model = AppViewModel(store: AlertStore(fileURL: url), marketData: marketData)
        XCTAssertNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "185"))
        XCTAssertNil(model.add(symbol: "NVDA", type: .sellAbove, targetText: "175"))

        marketData.sendCompletedTrade(symbol: "AAPL", price: 185)
        marketData.sendCompletedTrade(symbol: "NVDA", price: 175)

        XCTAssertEqual(model.store.alerts.filter { $0.status == .triggered }.count, 2)
        XCTAssertTrue(model.hasTriggeredAlert)
    }

    func testAllFourPriceDirectionsTriggerOnlyOnTheirRequestedSide() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let marketData = MockMarketDataService()
        let model = AppViewModel(store: AlertStore(fileURL: url), marketData: marketData)
        XCTAssertNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "100"))
        XCTAssertNil(model.add(symbol: "MSFT", type: .buyAbove, targetText: "100"))
        XCTAssertNil(model.add(symbol: "NVDA", type: .sellBelow, targetText: "100"))
        XCTAssertNil(model.add(symbol: "WMT", type: .sellAbove, targetText: "100"))

        marketData.sendCompletedTrade(symbol: "AAPL", price: 101)
        marketData.sendCompletedTrade(symbol: "MSFT", price: 99)
        marketData.sendCompletedTrade(symbol: "NVDA", price: 101)
        marketData.sendCompletedTrade(symbol: "WMT", price: 99)
        XCTAssertTrue(model.store.alerts.allSatisfy { $0.status == .active })

        marketData.sendCompletedTrade(symbol: "AAPL", price: 100)
        marketData.sendCompletedTrade(symbol: "MSFT", price: 100)
        marketData.sendCompletedTrade(symbol: "NVDA", price: 100)
        marketData.sendCompletedTrade(symbol: "WMT", price: 100)
        XCTAssertTrue(model.store.alerts.allSatisfy { $0.status == .triggered })
    }

    func testOlderTwoDirectionAlertValuesStillDecode() throws {
        let data = Data(#"""
        [{"id":"00000000-0000-0000-0000-000000000001","symbol":"AAPL","alertType":"buyBelow","targetPrice":185,"dateCreated":0,"status":"waitingForTrade","soundEnabled":true,"flashingEnabled":true,"marketDataFeed":"Mock Data"},
         {"id":"00000000-0000-0000-0000-000000000002","symbol":"MSFT","alertType":"sellAbove","targetPrice":500,"dateCreated":0,"status":"waitingForTrade","soundEnabled":true,"flashingEnabled":true,"marketDataFeed":"Mock Data"}]
        """#.utf8)

        let alerts = try JSONDecoder().decode([StockAlert].self, from: data)
        XCTAssertEqual(alerts.map(\.alertType), [.buyBelow, .sellAbove])
    }

    func testMinimalOlderAlertDecodesWithSafeDefaults() throws {
        let data = Data(#"""
        {"symbol":"AAPL","alertType":"buyBelow","targetPrice":185}
        """#.utf8)

        let alert = try JSONDecoder().decode(StockAlert.self, from: data)

        XCTAssertEqual(alert.status, .waitingForTrade)
        XCTAssertTrue(alert.soundEnabled)
        XCTAssertTrue(alert.flashingEnabled)
        XCTAssertEqual(alert.marketDataFeed, "Mock Data")
        XCTAssertNotNil(alert.id)
    }

    func testStoreRecoversValidAlertsWhenOneRecordIsDamaged() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data(#"""
        [
          {"symbol":"AAPL","alertType":"buyBelow","targetPrice":185},
          {"symbol":"BROKEN","alertType":"buyBelow","targetPrice":"not-a-price"}
        ]
        """#.utf8)
        try data.write(to: url)

        let store = AlertStore(fileURL: url)

        XCTAssertEqual(store.alerts.map(\.symbol), ["AAPL"])
        XCTAssertEqual(store.persistenceError, "Some damaged saved alerts could not be loaded.")
    }

    func testTriggeredAlertDoesNotRetriggerAndCanBeReset() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let marketData = MockMarketDataService()
        let model = AppViewModel(store: AlertStore(fileURL: url), marketData: marketData)
        XCTAssertNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "185"))
        marketData.sendCompletedTrade(symbol: "AAPL", price: 184)
        let firstTriggerDate = model.store.alerts[0].dateTriggered

        marketData.sendCompletedTrade(symbol: "AAPL", price: 183)
        XCTAssertEqual(model.store.alerts[0].dateTriggered, firstTriggerDate)

        model.reset(model.store.alerts[0])
        XCTAssertEqual(model.store.alerts[0].status, .active)
        marketData.sendCompletedTrade(symbol: "AAPL", price: 182)
        XCTAssertEqual(model.store.alerts[0].status, .active)
        marketData.sendCompletedTrade(symbol: "AAPL", price: 186)
        XCTAssertEqual(model.store.alerts[0].status, .active)
        marketData.sendCompletedTrade(symbol: "AAPL", price: 182)
        XCTAssertEqual(model.store.alerts[0].status, .triggered)
    }

    func testResetAllTriggeredWaitsForConditionsToClear() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let marketData = MockMarketDataService()
        let model = AppViewModel(store: AlertStore(fileURL: url), marketData: marketData)
        XCTAssertNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "185"))
        XCTAssertNil(model.add(symbol: "NVDA", type: .sellAbove, targetText: "175"))
        marketData.sendCompletedTrade(symbol: "AAPL", price: 184)
        marketData.sendCompletedTrade(symbol: "NVDA", price: 176)

        model.resetAllTriggered()
        XCTAssertEqual(model.triggeredCount, 0)
        marketData.sendCompletedTrade(symbol: "AAPL", price: 183)
        marketData.sendCompletedTrade(symbol: "NVDA", price: 177)
        XCTAssertEqual(model.triggeredCount, 0)
    }

    func testOptionalNotePersistsAndCanBeClearedWithoutChangingAlertState() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let marketData = MockMarketDataService()
        let model = AppViewModel(store: AlertStore(fileURL: url), marketData: marketData)
        XCTAssertNil(model.add(symbol: "AAPL", type: .buyBelow, targetText: "185", noteText: "Watching support\nPossible bounce"))
        marketData.sendCompletedTrade(symbol: "AAPL", price: 184)
        let triggered = model.store.alerts[0]
        let triggerDate = triggered.dateTriggered
        let tradePrice = triggered.lastTradePrice

        XCTAssertNil(model.edit(triggered, type: triggered.alertType, targetText: "185", noteText: "Updated local note"))
        XCTAssertEqual(model.store.alerts[0].note, "Updated local note")
        XCTAssertEqual(model.store.alerts[0].status, .triggered)
        XCTAssertEqual(model.store.alerts[0].dateTriggered, triggerDate)
        XCTAssertEqual(model.store.alerts[0].lastTradePrice, tradePrice)

        let reloaded = AlertStore(fileURL: url)
        XCTAssertEqual(reloaded.alerts[0].note, "Updated local note")

        XCTAssertNil(model.edit(model.store.alerts[0], type: .buyBelow, targetText: "185", noteText: "  \n "))
        XCTAssertNil(model.store.alerts[0].note)
        XCTAssertEqual(model.store.alerts[0].status, .triggered)
    }

    func testAlertWithoutNotePersistsNormally() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let model = AppViewModel(store: AlertStore(fileURL: url), marketData: MockMarketDataService())
        XCTAssertNil(model.add(symbol: "MSFT", type: .sellAbove, targetText: "500"))
        XCTAssertNil(model.store.alerts[0].note)
        XCTAssertNil(AlertStore(fileURL: url).alerts[0].note)
    }

    func testChangingFeedsClearsStaleNonTriggeredPrice() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let mock = MockMarketDataService()
        let model = AppViewModel(store: AlertStore(fileURL: url), marketData: mock)
        XCTAssertNil(model.add(symbol: "AAPL", type: .sellAbove, targetText: "500"))
        mock.sendCompletedTrade(symbol: "AAPL", price: 200)
        XCTAssertEqual(model.store.alerts[0].lastTradePrice, 200)

        model.useAlpaca(key: "test-key", secret: "test-secret", feed: .iex)

        XCTAssertNil(model.store.alerts[0].lastTradePrice)
        XCTAssertNil(model.store.alerts[0].lastTradeTimestamp)
        XCTAssertEqual(model.store.alerts[0].status, .waitingForTrade)
        XCTAssertEqual(model.store.alerts[0].marketDataFeed, "IEX Real-Time Trades")
    }

    func testLaunchingWithLiveFeedClearsTriggeredMockPrice() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alerts.json")
        let store = AlertStore(fileURL: url)
        var alert = StockAlert(symbol: "AAPL", alertType: .buyBelow, targetPrice: 185)
        alert.lastTradePrice = 100
        alert.lastTradeTimestamp = Date()
        alert.lastProcessedTradeID = "mock-trade"
        alert.marketDataFeed = "Mock Data"
        alert.status = .triggered
        alert.dateTriggered = Date()
        store.add(alert)

        _ = AppViewModel(
            store: store,
            marketData: AlpacaMarketDataService(key: "", secret: "", feed: .iex)
        )

        XCTAssertNil(store.alerts[0].lastTradePrice)
        XCTAssertNil(store.alerts[0].lastTradeTimestamp)
        XCTAssertNil(store.alerts[0].dateTriggered)
        XCTAssertEqual(store.alerts[0].status, .dataUnavailable)
        XCTAssertEqual(store.alerts[0].marketDataFeed, "IEX Real-Time Trades")
    }
}
