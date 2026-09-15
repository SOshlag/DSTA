import Foundation

enum MarketConnectionStatus: String {
    case connecting = "Connecting"
    case connected = "Connected"
    case reconnecting = "Reconnecting"
    case disconnected = "Disconnected"
    case authenticationError = "Authentication Error"
    case dataPermissionError = "Data Permission Error"
}

@MainActor
protocol MarketDataService: AnyObject {
    var feedName: String { get }
    var connectionStatus: MarketConnectionStatus { get }
    var onTrade: ((CompletedTrade) -> Void)? { get set }
    var onStatusChange: ((MarketConnectionStatus) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    func connect()
    func disconnect()
    func subscribe(to symbols: Set<String>)
    func unsubscribe(from symbols: Set<String>)
}
