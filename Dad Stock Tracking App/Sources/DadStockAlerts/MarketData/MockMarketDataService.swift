import Foundation

@MainActor
final class MockMarketDataService: MarketDataService {
    let feedName = "Mock Data"
    private(set) var connectionStatus: MarketConnectionStatus = .disconnected
    var onTrade: ((CompletedTrade) -> Void)?
    var onStatusChange: ((MarketConnectionStatus) -> Void)?
    var onError: ((String) -> Void)?

    private var symbols = Set<String>()
    private var prices: [String: Decimal] = [:]
    private var timer: Timer?

    func connect() {
        connectionStatus = .connected
        onStatusChange?(.connected)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.publishTrades() }
        }
    }

    func disconnect() {
        timer?.invalidate()
        timer = nil
        connectionStatus = .disconnected
        onStatusChange?(.disconnected)
    }

    func subscribe(to symbols: Set<String>) { self.symbols.formUnion(symbols) }
    func unsubscribe(from symbols: Set<String>) { self.symbols.subtract(symbols) }

    /// Sends a completed trade at an exact price for development and tests.
    func sendCompletedTrade(
        symbol: String,
        price: Decimal,
        timestamp: Date = Date(),
        tradeID: String = UUID().uuidString
    ) {
        prices[symbol] = price
        emit(symbol: symbol, price: price, timestamp: timestamp, tradeID: tradeID)
    }

    private func publishTrades() {
        for symbol in symbols.sorted() {
            let current = prices[symbol] ?? Decimal(Int.random(in: 80...300))
            let cents = Decimal(Int.random(in: -125...125)) / 100
            let next = max(Decimal(string: "0.01")!, current + cents)
            prices[symbol] = next
            emit(symbol: symbol, price: next, timestamp: Date(), tradeID: UUID().uuidString)
        }
    }

    private func emit(symbol: String, price: Decimal, timestamp: Date, tradeID: String) {
        onTrade?(CompletedTrade(symbol: symbol, price: price, timestamp: timestamp, tradeID: tradeID, exchangeID: "MOCK", feedID: feedName))
    }
}
