import AppKit
import SwiftUI

struct TriggeredAlertPreviewView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38, weight: .bold))
            Text("BUY PRICE REACHED")
                .font(.appArialBold(22))
                .tracking(1.4)
            Text("AAPL").font(.appArialBold(36))
            HStack(spacing: 34) {
                value("LAST COMPLETED TRADE", "$184.95")
                value("BUY BELOW TARGET", "$185.00")
            }
            Divider().overlay(.white.opacity(0.35))
            HStack {
                value("TRADE TIME", AppFormatters.date.string(from: Date()))
                Spacer()
                value("ALERT TRIGGERED", AppFormatters.date.string(from: Date()))
            }
            Text("Preview only · Mock Data · Alerts use completed trades only")
                .font(.appArialBold(11))
                .foregroundStyle(.white.opacity(0.72))
            HStack {
                Button("Dismiss") { PreviewAlertWindowController.shared.close() }
                Button("Reset Alert") { PreviewAlertWindowController.shared.close() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green.opacity(0.72))
            }
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(width: 500, height: 390)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [Color.green.opacity(pulse ? 0.58 : 0.28), Color.black.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.green.opacity(0.55), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func value(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.appArialBold(10)).foregroundStyle(.white.opacity(0.65))
            Text(text).font(.appArialBold(18))
        }
    }
}

@MainActor
final class PreviewAlertWindowController {
    static let shared = PreviewAlertWindowController()
    private var window: NSWindow?

    func show() {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 390),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Stock Alert Preview"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
        window.center()
        window.contentView = NSHostingView(rootView: TriggeredAlertPreviewView())
        self.window = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.orderOut(nil)
    }
}

struct TriggeredStockAlertView: View {
    let alert: StockAlert
    let model: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            Text(alert.alertType.isBuy ? "BUY PRICE REACHED" : "SELL PRICE REACHED")
                .font(.appArialBold(22)).tracking(1.2)
            Text(alert.symbol).font(.appArialBold(40))
            HStack(spacing: 36) {
                value("LAST COMPLETED TRADE", alert.lastTradePrice.map(AppFormatters.money) ?? "—")
                value("TARGET", AppFormatters.money(alert.targetPrice))
            }
            Text("Trade: \(alert.lastTradeTimestamp.map(AppFormatters.date.string) ?? "—")")
                .font(.appArialBold(11)).foregroundStyle(.secondary)
            if let note = alert.note, !note.isEmpty {
                VStack(spacing: 4) {
                    Text("NOTE").font(.appArialBold(10)).foregroundStyle(.secondary)
                    Text(note).font(.appArialBold(12)).multilineTextAlignment(.center).lineLimit(3)
                }
            }
            HStack {
                Button("Dismiss") { TriggeredAlertWindowController.shared.hide() }
                Button("Reset Alert") {
                    model.reset(alert)
                    TriggeredAlertWindowController.shared.hide()
                }.buttonStyle(.borderedProminent).tint(alert.alertType.isBuy ? .green : .red)
                Button("Edit Alert") {
                    TriggeredAlertWindowController.shared.hide()
                    DesktopManagerWindowController.shared.show(model: model)
                }
                Button("Delete Alert", role: .destructive) {
                    model.delete(alert)
                    TriggeredAlertWindowController.shared.hide()
                }
            }
        }
        .padding(28)
        .frame(width: 540, height: 370)
        .background((alert.alertType.isBuy ? Color.green : Color.red).opacity(pulse ? 0.34 : 0.18))
        .background(.ultraThinMaterial)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func value(_ label: String, _ text: String) -> some View {
        VStack(spacing: 5) {
            Text(label).font(.appArialBold(10)).foregroundStyle(.secondary)
            Text(text).font(.appArialBold(21))
        }
    }
}

@MainActor
final class TriggeredAlertWindowController {
    static let shared = TriggeredAlertWindowController()
    private var window: NSWindow?

    func show(alert: StockAlert, model: AppViewModel) {
        let window = window ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 370),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Stock Alert Triggered"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
        window.contentView = NSHostingView(rootView: TriggeredStockAlertView(alert: alert, model: model))
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() { window?.orderOut(nil) }
}
