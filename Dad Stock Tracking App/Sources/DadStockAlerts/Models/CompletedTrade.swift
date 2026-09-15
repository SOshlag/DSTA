import Foundation

/// A provider-reported completed trade. Quote events are intentionally not modeled.
struct CompletedTrade: Sendable {
    let symbol: String
    let price: Decimal
    let timestamp: Date
    let tradeID: String?
    let exchangeID: String?
    let feedID: String
}
