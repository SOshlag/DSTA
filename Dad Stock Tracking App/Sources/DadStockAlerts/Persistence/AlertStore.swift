import Foundation

@MainActor
final class AlertStore: ObservableObject {
    @Published private(set) var alerts: [StockAlert] = []
    @Published var persistenceError: String?

    private let fileURL: URL
    private var pendingSaveTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL
        load()
    }

    static var defaultURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DadStockAlerts", isDirectory: true)
        return directory.appendingPathComponent("alerts.json")
    }

    func add(_ alert: StockAlert) { alerts.append(alert); saveNow() }
    func delete(id: UUID) { alerts.removeAll { $0.id == id }; saveNow() }

    /// Live feeds can deliver many trades per second, and each one updates an
    /// alert's last-trade fields. `coalescingSave` batches those updates into
    /// at most one disk write per second; meaningful state changes should keep
    /// the default immediate save.
    func replace(_ alert: StockAlert, coalescingSave: Bool = false) {
        guard let index = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[index] = alert
        if coalescingSave { scheduleSave() } else { saveNow() }
    }

    /// Writes any batched changes immediately, e.g. before the app quits.
    func flushPendingSave() {
        guard pendingSaveTask != nil else { return }
        saveNow()
    }

    func isDuplicate(symbol: String, type: AlertType, target: Decimal) -> Bool {
        alerts.contains { $0.symbol == symbol && $0.alertType == type && $0.targetPrice == target }
    }

    private func scheduleSave() {
        guard pendingSaveTask == nil else { return }
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            self.saveNow()
        }
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

    private func saveNow() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(alerts)
            try data.write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch { persistenceError = "Alerts could not be saved." }
    }
}
