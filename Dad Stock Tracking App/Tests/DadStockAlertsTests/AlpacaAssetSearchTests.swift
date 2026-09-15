import XCTest
@testable import DadStockAlerts

@MainActor
final class AlpacaAssetSearchTests: XCTestCase {
    func testAssetDirectoryDecodingExcludesInactiveAndOTCAssets() {
        let data = Data(#"""
        [
          {"symbol":"AAPL","name":"Apple Inc.","exchange":"NASDAQ","status":"active","class":"us_equity"},
          {"symbol":"OLD","name":"Old Company","exchange":"NYSE","status":"inactive","class":"us_equity"},
          {"symbol":"OTCX","name":"OTC Company","exchange":"OTC","status":"active","class":"us_equity"}
        ]
        """#.utf8)

        XCTAssertEqual(
            AlpacaAssetSearchService.decodeAssets(from: data),
            [StockSymbolSuggestion(symbol: "AAPL", name: "Apple Inc.", exchange: "NASDAQ")]
        )
    }

    func testSymbolAndCompanyNameMatchesPrioritizeExactTicker() {
        let assets = [
            StockSymbolSuggestion(symbol: "AAPL", name: "Apple Inc.", exchange: "NASDAQ"),
            StockSymbolSuggestion(symbol: "APLE", name: "Apple Hospitality REIT", exchange: "NYSE"),
            StockSymbolSuggestion(symbol: "MSFT", name: "Microsoft Corporation", exchange: "NASDAQ")
        ]

        XCTAssertEqual(AlpacaAssetSearchService.matches(query: "AAPL", in: assets).first?.symbol, "AAPL")
        XCTAssertEqual(AlpacaAssetSearchService.matches(query: "micro", in: assets).first?.symbol, "MSFT")
    }
}
