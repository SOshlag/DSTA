import Foundation

enum AlertStatus: String, Codable {
    case active, paused, triggered, waitingForTrade, dataUnavailable

    var title: String {
        switch self {
        case .active: "Monitoring"
        case .paused: "Paused"
        case .triggered: "Triggered"
        case .waitingForTrade: "Waiting for Trade"
        case .dataUnavailable: "Data Unavailable"
        }
    }
}
