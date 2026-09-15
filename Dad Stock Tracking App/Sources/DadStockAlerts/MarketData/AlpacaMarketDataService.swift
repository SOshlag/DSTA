import Foundation

enum AlpacaFeed: String, CaseIterable, Identifiable {
    case iex, delayedSIP = "delayed_sip", sip
    var id: Self { self }
    var title: String {
        switch self {
        case .iex: "IEX Real-Time Trades"
        case .delayedSIP: "Delayed SIP Trade Data"
        case .sip: "SIP Real-Time Trades"
        }
    }
}

@MainActor
final class AlpacaMarketDataService: MarketDataService {
    let feed: AlpacaFeed
    var feedName: String { feed.title }
    private(set) var connectionStatus: MarketConnectionStatus = .disconnected
    var onTrade: ((CompletedTrade) -> Void)?
    var onStatusChange: ((MarketConnectionStatus) -> Void)?
    var onError: ((String) -> Void)?

    private let key: String
    private let secret: String
    private var task: URLSessionWebSocketTask?
    private var symbols = Set<String>()
    private var authenticated = false
    private var shouldReconnect = false
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    init(key: String, secret: String, feed: AlpacaFeed) {
        self.key = key
        self.secret = secret
        self.feed = feed
    }

    func connect() {
        guard !key.isEmpty, !secret.isEmpty else {
            updateStatus(.authenticationError)
            onError?("Alpaca API credentials are missing.")
            return
        }
        guard task == nil else { return }
        reconnectTask?.cancel()
        reconnectTask = nil
        shouldReconnect = true
        authenticated = false
        updateStatus(reconnectAttempt == 0 ? .connecting : .reconnecting)
        let url = URL(string: "wss://stream.data.alpaca.markets/v2/\(feed.rawValue)")!
        let socket = URLSession.shared.webSocketTask(with: url)
        task = socket
        socket.resume()
        startHeartbeat(for: socket)
        Task { await receiveLoop(socket) }
    }

    func disconnect() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        authenticated = false
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        updateStatus(.disconnected)
    }

    func subscribe(to symbols: Set<String>) {
        self.symbols.formUnion(symbols)
        if authenticated {
            send(action: "subscribe", symbols: symbols)
            fetchLatestTrades(for: symbols)
        }
    }

    func unsubscribe(from symbols: Set<String>) {
        self.symbols.subtract(symbols)
        if authenticated { send(action: "unsubscribe", symbols: symbols) }
    }

    private func receiveLoop(_ socket: URLSessionWebSocketTask) async {
        do {
            while task === socket {
                let message = try await socket.receive()
                let data: Data
                switch message {
                case .data(let value): data = value
                case .string(let value): data = Data(value.utf8)
                @unknown default: continue
                }
                handle(data)
            }
        } catch {
            guard shouldReconnect, task === socket else { return }
            beginReconnect(from: socket, message: "Market data disconnected. Reconnecting…")
        }
    }

    func handle(_ data: Data) {
        guard let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            onError?("The market-data service returned an invalid response.")
            return
        }
        for message in messages {
            if message["T"] as? String == "success" {
                switch message["msg"] as? String {
                case "connected": sendJSON(["action": "auth", "key": key, "secret": secret])
                case "authenticated":
                    authenticated = true
                    reconnectAttempt = 0
                    updateStatus(.connected)
                    send(action: "subscribe", symbols: symbols)
                    fetchLatestTrades(for: symbols)
                default: break
                }
            } else if message["T"] as? String == "error" {
                let code = (message["code"] as? NSNumber)?.intValue ?? 0
                let detail = message["msg"] as? String ?? "Market-data connection error."
                var shouldReportDetail = true
                if code == 401 || code == 402 {
                    stopForTerminalError(status: .authenticationError)
                } else if code == 409 {
                    stopForTerminalError(status: .dataPermissionError)
                } else if code == 406 {
                    shouldReportDetail = false
                    beginReconnect(
                        from: task,
                        minimumDelay: 15,
                        message: "Another Alpaca market-data session is active. Retrying automatically…"
                    )
                } else if code == 404 || code == 407 || code >= 500 {
                    beginReconnect(from: task, message: "Market data interrupted. Reconnecting…")
                }
                if shouldReportDetail { onError?(detail) }
            }
        }
        for trade in Self.completedTrades(from: data, feedName: feedName) { onTrade?(trade) }
    }

    static func completedTrades(from data: Data, feedName: String) -> [CompletedTrade] {
        guard let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return messages.compactMap { item in
            guard item["T"] as? String == "t",
                  let symbol = item["S"] as? String, !symbol.isEmpty,
                  let number = item["p"] as? NSNumber, number.decimalValue > 0,
                  let timestampText = item["t"] as? String,
                  let timestamp = formatter.date(from: timestampText) else { return nil }
            let tradeID = (item["i"] as? NSNumber)?.stringValue ?? item["i"] as? String
            return CompletedTrade(symbol: symbol, price: number.decimalValue, timestamp: timestamp, tradeID: tradeID, exchangeID: item["x"] as? String, feedID: feedName)
        }
    }

    /// Decodes Alpaca's multi-symbol latest-trades REST response.
    static func latestTrades(from data: Data, feedName: String) -> [CompletedTrade] {
        guard let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let trades = response["trades"] as? [String: Any] else { return [] }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return trades.compactMap { symbol, value in
            guard let item = value as? [String: Any],
                  let number = item["p"] as? NSNumber, number.decimalValue > 0,
                  let timestampText = item["t"] as? String,
                  let timestamp = formatter.date(from: timestampText) else { return nil }
            let tradeID = (item["i"] as? NSNumber)?.stringValue ?? item["i"] as? String
            return CompletedTrade(
                symbol: symbol,
                price: number.decimalValue,
                timestamp: timestamp,
                tradeID: tradeID,
                exchangeID: item["x"] as? String,
                feedID: feedName
            )
        }
    }

    private func fetchLatestTrades(for symbols: Set<String>) {
        guard !symbols.isEmpty else { return }
        var components = URLComponents(string: "https://data.alpaca.markets/v2/stocks/trades/latest")!
        components.queryItems = [
            URLQueryItem(name: "symbols", value: symbols.sorted().joined(separator: ",")),
            URLQueryItem(name: "feed", value: feed.rawValue)
        ]
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "APCA-API-KEY-ID")
        request.setValue(secret, forHTTPHeaderField: "APCA-API-SECRET-KEY")
        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { return }
                guard http.statusCode == 200 else {
                    // Snapshot loading is supplemental. A failed snapshot must
                    // not invalidate an authenticated live stream.
                    self.onError?("Could not load the latest completed trades (HTTP \(http.statusCode)).")
                    return
                }
                for trade in Self.latestTrades(from: data, feedName: self.feedName) {
                    self.onTrade?(trade)
                }
            } catch {
                self.onError?("Could not load the latest completed trades. Live streaming will continue.")
            }
        }
    }

    private func send(action: String, symbols: Set<String>) {
        guard !symbols.isEmpty else { return }
        sendJSON(["action": action, "trades": symbols.sorted()])
    }

    private func sendJSON(_ value: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: value), let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { [weak self] error in
            if error != nil { Task { @MainActor in self?.onError?("Could not send a market-data request.") } }
        }
    }

    private func beginReconnect(
        from socket: URLSessionWebSocketTask?,
        minimumDelay: Double = 0,
        message: String
    ) {
        guard shouldReconnect || task == nil else { return }
        if let socket, let task, task !== socket { return }
        heartbeatTask?.cancel()
        heartbeatTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        task = nil
        authenticated = false
        updateStatus(.reconnecting)
        onError?(message)
        scheduleReconnect(minimumDelay: minimumDelay)
    }

    private func scheduleReconnect(minimumDelay: Double = 0) {
        guard reconnectTask == nil else { return }
        reconnectAttempt += 1
        let delay = max(minimumDelay, min(30.0, pow(2.0, Double(min(reconnectAttempt, 5)))))
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.reconnectTask = nil
            if self.shouldReconnect { self.connect() }
        }
    }

    private func startHeartbeat(for socket: URLSessionWebSocketTask) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self, weak socket] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, let self, let socket, self.task === socket else { return }
                socket.sendPing { [weak self, weak socket] error in
                    guard error != nil else { return }
                    Task { @MainActor in
                        guard let self, let socket, self.task === socket else { return }
                        self.beginReconnect(from: socket, message: "Market data heartbeat failed. Reconnecting…")
                    }
                }
            }
        }
    }

    private func stopForTerminalError(status: MarketConnectionStatus) {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        authenticated = false
        task?.cancel(with: .policyViolation, reason: nil)
        task = nil
        updateStatus(status)
    }

    private func updateStatus(_ status: MarketConnectionStatus) {
        connectionStatus = status
        onStatusChange?(status)
    }
}
