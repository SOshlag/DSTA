import SwiftUI

struct AlertListView: View {
    @EnvironmentObject private var model: AppViewModel
    var compact = false

    var body: some View {
        if model.store.alerts.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "bell").font(.largeTitle).foregroundStyle(.secondary)
                Text("No Alerts").font(.appArialBold(14))
                Text("Add a price alert above to begin receiving mock completed trades.").foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(model.store.alerts) { alert in
                AlertRow(alert: alert, compact: compact)
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
        }
    }
}

private struct AlertRow: View {
    @EnvironmentObject private var model: AppViewModel
    let alert: StockAlert
    let compact: Bool

    var body: some View {
        if compact { compactRow } else { wideRow }
    }

    private var compactRow: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(alert.symbol, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.appArialBold(17)).tracking(1.2)
                Spacer()
                statusPill
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LAST TRADE").font(.appArialBold(10)).foregroundStyle(.secondary)
                    if let price = alert.lastTradePrice {
                        Text(AppFormatters.money(price)).font(.appArialBold(20))
                    } else { Text("Waiting for latest trade…").font(.appArialBold(13)).foregroundStyle(.secondary) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(alert.alertType.title.uppercased()).font(.appArialBold(10)).foregroundStyle(conditionColor)
                    Text(AppFormatters.money(alert.targetPrice)).font(.appArialBold(14))
                }
            }
            HStack {
                Label(alert.marketDataFeed, systemImage: "dot.radiowaves.left.and.right").font(.appArialBold(10)).foregroundStyle(.secondary)
                Spacer()
                if alert.status == .triggered {
                    Button("Reset") { model.reset(alert) }.controlSize(.small)
                } else {
                    Button(alert.status == .paused ? "Resume" : "Pause") { model.togglePause(alert) }.controlSize(.small)
                }
                Button(role: .destructive) { model.delete(alert) } label: { Image(systemName: "trash") }.buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(alert.status == .triggered ? Color.green.opacity(0.75) : Color(red: 0.76, green: 0.62, blue: 0.34).opacity(0.20)))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .padding(.vertical, 3)
    }

    private var wideRow: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.82, green: 0.68, blue: 0.38))
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 5) {
                    Text(alert.symbol).font(.appArialBold(20)).tracking(1.4)
                    statusPill
                }
            }.frame(width: 155, alignment: .leading)

            Divider().frame(height: 50)

            VStack(alignment: .leading, spacing: 4) {
                metricLabel("LAST TRADE")
                if let price = alert.lastTradePrice {
                    Text(AppFormatters.money(price)).font(.appArialBold(19))
                    Text(alert.lastTradeTimestamp.map(AppFormatters.date.string) ?? "—").font(.appArialBold(11)).foregroundStyle(.secondary)
                } else { Text("Waiting for latest trade…").foregroundStyle(.secondary) }
            }.frame(width: 165, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                metricLabel(alert.alertType.title.uppercased()).foregroundStyle(conditionColor)
                Text(AppFormatters.money(alert.targetPrice)).font(.appArialBold(17))
                Text(distanceText.replacingOccurrences(of: "\n", with: " · "))
                    .font(.appArialBold(10)).foregroundStyle(.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)

            Label(alert.marketDataFeed.uppercased(), systemImage: "dot.radiowaves.left.and.right")
                .font(.appArialBold(9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(.black.opacity(0.16), in: Capsule())

            if alert.status == .triggered {
                Button("Reset") { model.reset(alert) }
            } else {
                Button(alert.status == .paused ? "Resume" : "Pause") { model.togglePause(alert) }
            }
            Button(role: .destructive) { model.delete(alert) } label: { Image(systemName: "trash") }
                .accessibilityLabel("Delete \(alert.symbol) alert")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            alert.status == .triggered ? Color.green.opacity(0.30) : Color.black.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
            if alert.status == .triggered {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green.opacity(0.78), lineWidth: 2)
            }
        }
        .listRowBackground(alert.status == .triggered ? Color.green.opacity(0.10) : Color.clear)
    }

    private func metricLabel(_ text: String) -> some View {
        Text(text).font(.appArialBold(9)).tracking(1.1).foregroundStyle(.secondary)
    }

    private var statusPill: some View {
        Label(alert.status.title.uppercased(), systemImage: statusIcon)
            .font(.appArialBold(9))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.13), in: Capsule())
    }

    private var conditionColor: Color { alert.alertType.isBuy ? .green : .red }
    private var statusColor: Color {
        switch alert.status {
        case .active: .blue
        case .paused: .orange
        case .triggered: .green
        case .waitingForTrade: .secondary
        case .dataUnavailable: .red
        }
    }
    private var statusIcon: String {
        switch alert.status {
        case .active: "checkmark.circle.fill"
        case .paused: "pause.circle.fill"
        case .triggered: "bell.badge.fill"
        case .waitingForTrade: "clock.fill"
        case .dataUnavailable: "wifi.slash"
        }
    }
    private var distanceText: String {
        guard let price = alert.lastTradePrice else { return "Distance unavailable" }
        let difference = price - alert.targetPrice
        let direction = difference >= 0 ? "above" : "below"
        let absolute = difference < 0 ? -difference : difference
        let percent = alert.targetPrice == 0 ? 0 : absolute / alert.targetPrice * 100
        return "\(AppFormatters.money(absolute)) \(direction)\n\(NSDecimalNumber(decimal: percent).stringValue)% away"
    }
}
