import XCTest
@testable import DadStockAlerts

@MainActor
final class AlpacaMarketDataTests: XCTestCase {
    func testDecoderEmitsCompletedTradesAndIgnoresQuotesAndBars() {
        let payload = Data(#"""
        [
            {"T":"q","S":"AAPL","bp":184.90,"ap":185.10,"t":"2026-07-15T14:30:00.123456789Z"},
            {"T":"b","S":"AAPL","c":185.00,"t":"2026-07-15T14:30:00Z"},
            {"T":"t","S":"AAPL","p":184.95,"t":"2026-07-15T14:30:01.123456789Z","i":42,"x":"V"}
        ]
        """#.utf8)

        let trades = AlpacaMarketDataService.completedTrades(from: payload, feedName: "IEX Real-Time Trades")

        XCTAssertEqual(trades.count, 1)
        XCTAssertEqual(trades[0].symbol, "AAPL")
        XCTAssertEqual(trades[0].price, Decimal(string: "184.95"))
        XCTAssertEqual(trades[0].tradeID, "42")
        XCTAssertEqual(trades[0].exchangeID, "V")
    }

    func testInvalidAndIncompleteTradeEventsAreIgnored() {
        let payload = Data(#"""
        [
            {"T":"t","S":"","p":184.95,"t":"2026-07-15T14:30:01.123Z"},
            {"T":"t","S":"AAPL","t":"2026-07-15T14:30:01.123Z"},
            {"T":"t","S":"AAPL","p":0,"t":"2026-07-15T14:30:01.123Z"}
        ]
        """#.utf8)
        XCTAssertTrue(AlpacaMarketDataService.completedTrades(from: payload, feedName: "IEX Real-Time Trades").isEmpty)
    }

    func testLatestTradesResponseIsDecodedForEverySymbol() {
        let payload = Data(#"""
        {"trades":{
            "AAPL":{"p":211.42,"t":"2026-07-15T20:00:00.123456789Z","i":101,"x":"V"},
            "MSFT":{"p":507.18,"t":"2026-07-15T19:59:58.123456789Z","i":202,"x":"V"}
        }}
        """#.utf8)

        let trades = AlpacaMarketDataService.latestTrades(from: payload, feedName: "IEX Real-Time Trades")

        XCTAssertEqual(trades.count, 2)
        XCTAssertEqual(trades.first(where: { $0.symbol == "AAPL" })?.price, Decimal(string: "211.42"))
        XCTAssertEqual(trades.first(where: { $0.symbol == "MSFT" })?.tradeID, "202")
    }

    func testMissingCredentialsFailGracefullyWithoutNetworkConnection() {
        let service = AlpacaMarketDataService(key: "", secret: "", feed: .iex)
        var errorMessage: String?
        service.onError = { errorMessage = $0 }
        service.connect()
        XCTAssertEqual(service.connectionStatus, .authenticationError)
        XCTAssertEqual(errorMessage, "Alpaca API credentials are missing.")
    }

    func testAuthenticationAndPermissionErrorsAreTerminal() {
        let authenticationService = AlpacaMarketDataService(key: "key", secret: "secret", feed: .iex)
        authenticationService.handle(Data(#"[{"T":"error","code":401,"msg":"not authenticated"}]"#.utf8))
        XCTAssertEqual(authenticationService.connectionStatus, .authenticationError)

        let permissionService = AlpacaMarketDataService(key: "key", secret: "secret", feed: .iex)
        permissionService.handle(Data(#"[{"T":"error","code":409,"msg":"insufficient subscription"}]"#.utf8))
        XCTAssertEqual(permissionService.connectionStatus, .dataPermissionError)

        let alreadyAuthenticatedService = AlpacaMarketDataService(key: "key", secret: "secret", feed: .iex)
        alreadyAuthenticatedService.handle(Data(#"[{"T":"error","code":403,"msg":"already authenticated"}]"#.utf8))
        XCTAssertNotEqual(alreadyAuthenticatedService.connectionStatus, .dataPermissionError)
    }
}
