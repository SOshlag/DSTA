import Foundation

struct StockSymbolSuggestion: Codable, Equatable, Identifiable {
    let symbol: String
    let name: String
    let exchange: String
    var id: String { symbol }
}

@MainActor
final class AlpacaAssetSearchService: ObservableObject {
    @Published private(set) var suggestions: [StockSymbolSuggestion] = []
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?

    private static var cachedAssets: [StockSymbolSuggestion]?
    private var query = ""

    func update(query rawQuery: String) {
        query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            suggestions = []
            message = nil
            return
        }
        if let assets = Self.cachedAssets {
            suggestions = Self.matches(query: query, in: assets)
            message = suggestions.isEmpty && query.count >= 2 ? "No active U.S. stocks or ETFs found." : nil
        } else if !isLoading {
            Task { await loadAssets() }
        }
    }

    func clear() {
        suggestions = []
        message = nil
    }

    private func loadAssets() async {
        let key = KeychainService.read(account: "apiKey")
        let secret = KeychainService.read(account: "apiSecret")
        guard !key.isEmpty, !secret.isEmpty else {
            message = "Connect Alpaca Market Data to enable stock suggestions."
            return
        }
        isLoading = true
        defer { isLoading = false }
        var components = URLComponents(string: "https://paper-api.alpaca.markets/v2/assets")!
        components.queryItems = [
            URLQueryItem(name: "status", value: "active"),
            URLQueryItem(name: "asset_class", value: "us_equity")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(key, forHTTPHeaderField: "APCA-API-KEY-ID")
        request.setValue(secret, forHTTPHeaderField: "APCA-API-SECRET-KEY")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                message = "Stock suggestions are temporarily unavailable."
                return
            }
            let assets = Self.decodeAssets(from: data)
            guard !assets.isEmpty else {
                message = "Stock suggestions are temporarily unavailable."
                return
            }
            Self.cachedAssets = assets
            suggestions = Self.matches(query: query, in: assets)
            message = suggestions.isEmpty && query.count >= 2 ? "No active U.S. stocks or ETFs found." : nil
        } catch {
            message = "Stock suggestions are temporarily unavailable."
        }
    }

    static func decodeAssets(from data: Data) -> [StockSymbolSuggestion] {
        struct Asset: Decodable {
            let symbol: String
            let name: String
            let exchange: String
            let status: String
            let assetClass: String

            enum CodingKeys: String, CodingKey {
                case symbol, name, exchange, status
                case assetClass = "class"
            }
        }
        guard let assets = try? JSONDecoder().decode([Asset].self, from: data) else { return [] }
        return assets.compactMap { asset in
            guard asset.status == "active", asset.assetClass == "us_equity", asset.exchange != "OTC" else { return nil }
            return StockSymbolSuggestion(symbol: asset.symbol, name: asset.name, exchange: asset.exchange)
        }
    }

    static func matches(query rawQuery: String, in assets: [StockSymbolSuggestion]) -> [StockSymbolSuggestion] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !query.isEmpty else { return [] }
        return assets
            .filter { $0.symbol.uppercased().contains(query) || $0.name.uppercased().contains(query) }
            .sorted {
                let leftRank = rank($0, query: query)
                let rightRank = rank($1, query: query)
                return leftRank == rightRank ? $0.symbol < $1.symbol : leftRank < rightRank
            }
            .prefix(6)
            .map { $0 }
    }

    private static func rank(_ asset: StockSymbolSuggestion, query: String) -> Int {
        if asset.symbol.uppercased() == query { return 0 }
        if asset.symbol.uppercased().hasPrefix(query) { return 1 }
        if asset.name.uppercased().hasPrefix(query) { return 2 }
        if asset.symbol.uppercased().contains(query) { return 3 }
        return 4
    }
}
