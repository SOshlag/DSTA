import Foundation

enum AlertType: String, Codable, CaseIterable, Identifiable {
    case buyBelow
    case buyAbove
    case sellBelow
    case sellAbove

    var id: Self { self }
    var title: String {
        switch self {
        case .buyBelow: "Buy Below"
        case .buyAbove: "Buy Above"
        case .sellBelow: "Sell Below"
        case .sellAbove: "Sell Above"
        }
    }

    var isBuy: Bool { self == .buyBelow || self == .buyAbove }
    var isAbove: Bool { self == .buyAbove || self == .sellAbove }
    var directionSystemImage: String { isAbove ? "arrow.up.circle" : "arrow.down.circle" }

    func isReached(price: Decimal, target: Decimal) -> Bool {
        isAbove ? price >= target : price <= target
    }
}
