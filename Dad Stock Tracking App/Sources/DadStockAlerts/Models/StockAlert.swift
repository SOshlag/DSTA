import Foundation

struct StockAlert: Identifiable, Codable, Equatable {
    var id = UUID()
    var symbol: String
    var alertType: AlertType
    var targetPrice: Decimal
    var lastTradePrice: Decimal?
    var lastTradeTimestamp: Date?
    var dateCreated = Date()
    var dateTriggered: Date?
    var status: AlertStatus = .waitingForTrade
    var soundEnabled = true
    var flashingEnabled = true
    var marketDataFeed = "Mock Data"
    var lastProcessedTradeID: String?
    /// After reset, wait for price to return to the safe side before rearming.
    var waitingForConditionToClear: Bool?
    var note: String?

    var sortableTypeTitle: String { alertType.title }
    var sortableStatusTitle: String { status.title }
    var sortableNote: String { note ?? "" }

    private enum CodingKeys: String, CodingKey {
        case id, symbol, alertType, targetPrice, lastTradePrice, lastTradeTimestamp
        case dateCreated, dateTriggered, status, soundEnabled, flashingEnabled
        case marketDataFeed, lastProcessedTradeID, waitingForConditionToClear, note
    }

    init(
        id: UUID = UUID(),
        symbol: String,
        alertType: AlertType,
        targetPrice: Decimal,
        lastTradePrice: Decimal? = nil,
        lastTradeTimestamp: Date? = nil,
        dateCreated: Date = Date(),
        dateTriggered: Date? = nil,
        status: AlertStatus = .waitingForTrade,
        soundEnabled: Bool = true,
        flashingEnabled: Bool = true,
        marketDataFeed: String = "Mock Data",
        lastProcessedTradeID: String? = nil,
        waitingForConditionToClear: Bool? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.alertType = alertType
        self.targetPrice = targetPrice
        self.lastTradePrice = lastTradePrice
        self.lastTradeTimestamp = lastTradeTimestamp
        self.dateCreated = dateCreated
        self.dateTriggered = dateTriggered
        self.status = status
        self.soundEnabled = soundEnabled
        self.flashingEnabled = flashingEnabled
        self.marketDataFeed = marketDataFeed
        self.lastProcessedTradeID = lastProcessedTradeID
        self.waitingForConditionToClear = waitingForConditionToClear
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        symbol = try values.decode(String.self, forKey: .symbol)
        alertType = try values.decode(AlertType.self, forKey: .alertType)
        targetPrice = try values.decode(Decimal.self, forKey: .targetPrice)
        lastTradePrice = try values.decodeIfPresent(Decimal.self, forKey: .lastTradePrice)
        lastTradeTimestamp = try values.decodeIfPresent(Date.self, forKey: .lastTradeTimestamp)
        dateCreated = try values.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        dateTriggered = try values.decodeIfPresent(Date.self, forKey: .dateTriggered)
        status = try values.decodeIfPresent(AlertStatus.self, forKey: .status) ?? .waitingForTrade
        soundEnabled = try values.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        flashingEnabled = try values.decodeIfPresent(Bool.self, forKey: .flashingEnabled) ?? true
        marketDataFeed = try values.decodeIfPresent(String.self, forKey: .marketDataFeed) ?? "Mock Data"
        lastProcessedTradeID = try values.decodeIfPresent(String.self, forKey: .lastProcessedTradeID)
        waitingForConditionToClear = try values.decodeIfPresent(Bool.self, forKey: .waitingForConditionToClear)
        note = try values.decodeIfPresent(String.self, forKey: .note)
    }
}
