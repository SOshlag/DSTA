import AppKit
import UserNotifications

/// Plays a sound and posts a macOS user notification when an alert triggers.
@MainActor
enum AlertNotifier {
    // UNUserNotificationCenter crashes outside an .app bundle, so `swift run`
    // from the bare SwiftPM executable must never touch it.
    private static var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    private static let delegate = BannerWhileActiveDelegate()

    static func requestPermissionIfNeeded() {
        guard canUseUserNotifications else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(for alert: StockAlert) {
        if alert.soundEnabled, NSSound(named: "Glass")?.play() != true {
            NSSound.beep()
        }
        guard canUseUserNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(alert.symbol): \(alert.alertType.isBuy ? "buy" : "sell") price reached"
        var lines = ["Target \(AppFormatters.money(alert.targetPrice))"]
        if let price = alert.lastTradePrice {
            lines.insert("Last trade \(AppFormatters.money(price))", at: 0)
        }
        content.body = lines.joined(separator: " · ")
        if alert.soundEnabled { content.sound = .default }
        let request = UNNotificationRequest(
            identifier: "triggered-\(alert.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Shows banners even while the app is frontmost, which is the common
    /// state for a menu-bar app.
    private final class BannerWhileActiveDelegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .sound])
        }
    }
}
