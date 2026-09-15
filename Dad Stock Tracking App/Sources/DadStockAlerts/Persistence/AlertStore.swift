import Foundation

@MainActor
final class AlertStore: ObservableObject {
    @Published private(set) var alerts: [StockAlert] = []
    @Published var persistenceError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL
        load()
    }

    static var defaultURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DadStockAlerts", isDirectory: true)
        return directory.appendingPathComponent("alerts.json")
    }

    func add(_ alert: StockAlert) { alerts.append(alert); save() }
    func delete(id: UUID) { alerts.removeAll { $0.id == id }; save() }
    func replace(_ alert: StockAlert) {
        guard let index = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[index] = alert
        save()
    }

    func isDuplicate(symbol: String, type: AlertType, target: Decimal) -> Bool {
        alerts.contains { $0.symbol == symbol && $0.alertType == type && $0.targetPrice == target }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            do {
                alerts = try JSONDecoder().decode([StockAlert].self, from: data)
            } catch {
                guard let records = try JSONSerialization.jsonObject(with: data) as? [Any] else { throw error }
                let decoder = JSONDecoder()
                let recovered = records.compactMap { record -> StockAlert? in
                    guard JSONSerialization.isValidJSONObject(record),
                          let recordData = try? JSONSerialization.data(withJSONObject: record) else { return nil }
                    return try? decoder.decode(StockAlert.self, from: recordData)
                }
                guard !recovered.isEmpty || records.isEmpty else { throw error }
                alerts = recovered
                if recovered.count != records.count {
                    persistenceError = "Some damaged saved alerts could not be loaded."
                }
            }
        } catch {
            persistenceError = "Saved alerts could not be loaded."
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(alerts)
            try data.write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch { persistenceError = "Alerts could not be saved." }
    }
}
