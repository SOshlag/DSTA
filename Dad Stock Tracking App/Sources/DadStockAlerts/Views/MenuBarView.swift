import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STOCK ALERTS").font(.appArialBold(15)).tracking(1.4)
                Spacer()
                Label(model.marketData.feedName, systemImage: "dot.radiowaves.left.and.right")
                    .font(.appArialBold(9)).foregroundStyle(.secondary)
            }

            if let alert = model.primaryAlert {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(alert.symbol).font(.appArialBold(28)).tracking(1.4)
                        Spacer()
                        statusPill(alert)
                    }
                    HStack {
                        metric(alert.alertType.title.uppercased(), AppFormatters.money(alert.targetPrice))
                        Spacer()
                        if let price = alert.lastTradePrice {
                            metric("LAST TRADE", AppFormatters.money(price))
                        } else {
                            metric("LAST TRADE", "Waiting…")
                        }
                    }
                }
                .padding(14)
                .background(AppTheme.surfaceRaised.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.border))

                if alert.status == .triggered {
                    Button("Reset Alert") { model.reset(alert) }
                        .buttonStyle(.borderedProminent).tint(.green)
                } else {
                    Button(alert.status == .paused ? "Resume Alert" : "Pause Alert") {
                        model.togglePause(alert)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "bell.badge").font(.title2).foregroundStyle(AppTheme.gold)
                    Text("No alert is monitoring").font(.appArialBold(13))
                    Text("Open the main window to start one.").foregroundStyle(.white.opacity(0.58))
                }.frame(maxWidth: .infinity).padding(.vertical, 18)
            }

            Button {
                openMainWindow()
            } label: {
                Label("Open Main Window", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)

            Divider()
            Button("Quit Stock Alerts") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 340)
        .foregroundStyle(.white)
        .background(TechGridBackground())
        .preferredColorScheme(.dark)
        .font(.appArialBold(12))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.appArialBold(9)).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.appArialBold(16)).monospacedDigit().foregroundStyle(AppTheme.cyan)
        }
    }

    private func statusPill(_ alert: StockAlert) -> some View {
        Label(alert.status.title, systemImage: alert.status == .triggered ? "bell.fill" : alert.status == .paused ? "pause.circle.fill" : "checkmark.circle.fill")
            .font(.appArialBold(10))
            .foregroundStyle(alert.status == .triggered ? AppTheme.buy : alert.status == .paused ? Color.orange : Color(red: 0.45, green: 0.68, blue: 1.0))
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(AppTheme.surfaceRaised, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.border))
    }

    private func openMainWindow() {
        DesktopManagerWindowController.shared.show(model: model)
    }
}
