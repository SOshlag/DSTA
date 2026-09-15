import SwiftUI
import AppKit

final class StockAlertsAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { DesktopManagerWindowController.shared.reopen() }
        return true
    }
}

@main
struct DadStockAlertsApp: App {
    @NSApplicationDelegateAdaptor(StockAlertsAppDelegate.self) private var appDelegate
    @StateObject private var model: AppViewModel

    init() {
        let savedMode = UserDefaults.standard.string(forKey: "marketDataMode") ?? "mock"
        let initialService: MarketDataService
        if let feed = AlpacaFeed(rawValue: savedMode) {
            initialService = AlpacaMarketDataService(
                key: KeychainService.read(account: "apiKey"),
                secret: KeychainService.read(account: "apiSecret"),
                feed: feed
            )
        } else {
            initialService = MockMarketDataService()
        }
        let appModel = AppViewModel(marketData: initialService)
        _model = StateObject(wrappedValue: appModel)
        appModel.onAlertTriggered = { alert in
            TriggeredAlertWindowController.shared.show(alert: alert, model: appModel)
        }
        if CommandLine.arguments.contains("--preview-alert") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                PreviewAlertWindowController.shared.show()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            DesktopManagerWindowController.shared.show(model: appModel)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView().environmentObject(model)
        } label: {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .accessibilityLabel(model.hasTriggeredAlert
                    ? "Stock Alerts, \(model.triggeredCount) triggered"
                    : "Stock Alerts, \(model.activeCount) active")
        }.menuBarExtraStyle(.window)

    }
}
