import AppKit
import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    let store: AlertStore
    @Published private(set) var marketData: MarketDataService
    @Published private(set) var connectionStatus: MarketConnectionStatus = .disconnected
    @Published private(set) var marketDataMessage: String?
    private var storeObserver: AnyCancellable?
    private var subscribedSymbols = Set<String>()
    var onAlertTriggered: ((StockAlert) -> Void)?

    init(store: AlertStore? = nil, marketData: MarketDataService? = nil) {
        let resolvedStore = store ?? AlertStore()
        let resolvedMarketData = marketData ?? MockMarketDataService()
        self.store = resolvedStore
        self.marketData = resolvedMarketData
        storeObserver = resolvedStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        clearStalePrices(changingTo: resolvedMarketData.feedName)
        configure(resolvedMarketData)
        syncSubscriptions()
    }

    var activeCount: Int { store.alerts.filter { $0.status != .paused && $0.status != .triggered }.count }
    var triggeredCount: Int { store.alerts.filter { $0.status == .triggered }.count }
    var hasTriggeredAlert: Bool { triggeredCount > 0 }
    /// The alert shown in the menu-bar popover: the most recently triggered
    /// alert takes priority; otherwise the newest alert.
    var primaryAlert: StockAlert? {
        let triggered = store.alerts.filter { $0.status == .triggered }
        if let newestTriggered = triggered.max(by: {
            ($0.dateTriggered ?? .distantPast) < ($1.dateTriggered ?? .distantPast)
        }) {
            return newestTriggered
        }
        return store.alerts.max(by: { $0.dateCreated < $1.dateCreated })
    }

    func add(symbol rawSymbol: String, type: AlertType, targetText: String, noteText: String = "") -> String? {
        let symbol = rawSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !symbol.isEmpty else { return "Enter a stock symbol." }
        guard SymbolValidator.isValid(symbol) else { return "Enter a valid U.S. stock or ETF symbol." }
        let cleanedTarget = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTarget.isEmpty else { return "Enter a target price." }
        guard let target = Decimal(string: cleanedTarget, locale: Locale(identifier: "en_US_POSIX")) else { return "Enter a numeric target price." }
        guard target > 0 else { return "Enter a target price greater than zero." }
        guard !store.isDuplicate(symbol: symbol, type: type, target: target) else { return "That exact alert already exists." }
        store.add(StockAlert(symbol: symbol, alertType: type, targetPrice: target, marketDataFeed: marketData.feedName, note: normalizedNote(noteText)))
        syncSubscriptions()
        return nil
    }

    func delete(_ alert: StockAlert) { store.delete(id: alert.id); syncSubscriptions() }
    func edit(_ alert: StockAlert, type: AlertType, targetText: String, noteText: String) -> String? {
        guard let target = Decimal(string: targetText.trimmingCharacters(in: .whitespacesAndNewlines), locale: Locale(identifier: "en_US_POSIX")), target > 0 else {
            return "Enter a target price greater than zero."
        }
        if store.alerts.contains(where: { $0.id != alert.id && $0.symbol == alert.symbol && $0.alertType == type && $0.targetPrice == target }) {
            return "That exact alert already exists."
        }
        var updated = alert
        let triggerSettingsChanged = updated.alertType != type || updated.targetPrice != target
        updated.alertType = type
        updated.targetPrice = target
        updated.note = normalizedNote(noteText)
        if triggerSettingsChanged {
            updated.status = updated.lastTradePrice == nil ? .waitingForTrade : .active
            updated.dateTriggered = nil
            updated.waitingForConditionToClear = updated.lastTradePrice != nil
        }
        store.replace(updated)
        return nil
    }
    func togglePause(_ alert: StockAlert) {
        var updated = alert
        updated.status = alert.status == .paused ? (alert.lastTradePrice == nil ? .waitingForTrade : .active) : .paused
        store.replace(updated)
    }

    func reset(_ alert: StockAlert) {
        var updated = alert
        updated.dateTriggered = nil
        updated.status = updated.lastTradePrice == nil ? .waitingForTrade : .active
        updated.waitingForConditionToClear = updated.lastTradePrice != nil
        store.replace(updated)
    }

    func resetAllTriggered() {
        for alert in store.alerts where alert.status == .triggered {
            reset(alert)
        }
    }

    func useMockData() {
        UserDefaults.standard.set("mock", forKey: "marketDataMode")
        replaceMarketData(with: MockMarketDataService())
    }

    func useAlpaca(key: String, secret: String, feed: AlpacaFeed) {
        UserDefaults.standard.set(feed.rawValue, forKey: "marketDataMode")
        replaceMarketData(with: AlpacaMarketDataService(key: key, secret: secret, feed: feed))
    }

    private func receive(_ trade: CompletedTrade) {
        guard !trade.symbol.isEmpty, trade.price > 0 else { return }
        marketDataMessage = nil
        for alert in store.alerts where alert.symbol == trade.symbol {
            guard alert.status != .paused, alert.status != .triggered else { continue }
            guard alert.lastProcessedTradeID != trade.tradeID else { continue }
            // A slower REST snapshot can arrive after a newer WebSocket trade.
            // Never let delayed data move an alert backward in time.
            if let lastTimestamp = alert.lastTradeTimestamp,
               trade.timestamp < lastTimestamp { continue }
            var updated = alert
            updated.lastTradePrice = trade.price
            updated.lastTradeTimestamp = trade.timestamp
            updated.lastProcessedTradeID = trade.tradeID
            updated.marketDataFeed = marketData.feedName
            if updated.status == .waitingForTrade || updated.status == .dataUnavailable { updated.status = .active }
            let reachedTarget = updated.alertType.isReached(price: trade.price, target: updated.targetPrice)
            if updated.waitingForConditionToClear == true {
                if !reachedTarget { updated.waitingForConditionToClear = false }
                store.replace(updated)
                continue
            }
            if reachedTarget {
                updated.status = .triggered
                updated.dateTriggered = Date()
            }
            store.replace(updated)
            if reachedTarget { onAlertTriggered?(updated) }
        }
    }

    private func syncSubscriptions() {
        let desired = Set(store.alerts.map(\.symbol))
        marketData.unsubscribe(from: subscribedSymbols.subtracting(desired))
        marketData.subscribe(to: desired.subtracting(subscribedSymbols))
        subscribedSymbols = desired
    }

    private func replaceMarketData(with service: MarketDataService) {
        marketData.disconnect()
        subscribedSymbols.removeAll()
        clearStalePrices(changingTo: service.feedName)
        marketData = service
        configure(service)
        syncSubscriptions()
    }

    private func clearStalePrices(changingTo feedName: String) {
        for alert in store.alerts where alert.marketDataFeed != feedName {
            var updated = alert
            updated.lastTradePrice = nil
            updated.lastTradeTimestamp = nil
            updated.lastProcessedTradeID = nil
            updated.marketDataFeed = feedName
            updated.dateTriggered = nil
            updated.waitingForConditionToClear = false
            if updated.status != .paused { updated.status = .waitingForTrade }
            store.replace(updated)
        }
    }

    private func configure(_ service: MarketDataService) {
        service.onTrade = { [weak self] trade in self?.receive(trade) }
        service.onStatusChange = { [weak self] status in
            self?.connectionStatus = status
            if status == .connected {
                self?.marketDataMessage = nil
                self?.restoreAlertsAfterConnection()
            }
            if status == .disconnected || status == .authenticationError || status == .dataPermissionError {
                self?.markAlertsDataUnavailable()
            }
        }
        service.onError = { [weak self] message in self?.marketDataMessage = message }
        service.connect()
    }

    private func markAlertsDataUnavailable() {
        for alert in store.alerts where alert.status != .paused && alert.status != .triggered {
            var updated = alert
            updated.status = .dataUnavailable
            store.replace(updated)
        }
    }

    private func restoreAlertsAfterConnection() {
        for alert in store.alerts where alert.status == .dataUnavailable {
            var updated = alert
            updated.status = alert.lastTradePrice == nil ? .waitingForTrade : .active
            store.replace(updated)
        }
    }

    private func normalizedNote(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(400))
    }
}

enum SymbolValidator {
    static func isValid(_ symbol: String) -> Bool {
        symbol.range(of: #"^[A-Z]{1,5}([.-][A-Z]{1,2})?$"#, options: .regularExpression) != nil
    }
}
