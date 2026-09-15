import SwiftUI

struct MarketDataSettingsView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode = UserDefaults.standard.string(forKey: "marketDataMode") ?? "mock"
    @State private var apiKey = KeychainService.read(account: "apiKey")
    @State private var apiSecret = KeychainService.read(account: "apiSecret")
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Market Data").font(.appArialBold(21)).foregroundStyle(AppTheme.ink)
                    Text("Choose the completed-trade feed used for alert evaluation.")
                        .font(.appArialBold(10)).foregroundStyle(AppTheme.muted)
                }
            }

            Picker("Feed", selection: $mode) {
                Text("Mock Data").tag("mock")
                ForEach(AlpacaFeed.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .controlSize(.large)

            if mode != "mock" {
                TextField("Alpaca API Key", text: $apiKey).textFieldStyle(.roundedBorder).controlSize(.large)
                SecureField("Alpaca API Secret", text: $apiSecret).textFieldStyle(.roundedBorder).controlSize(.large)
                Text("Credentials are stored in the macOS Keychain and are never written to the project or alerts file.")
                    .font(.appArialBold(10)).foregroundStyle(.secondary)
                Link("Open Alpaca Market Data documentation", destination: URL(string: "https://docs.alpaca.markets/us/docs/market-data-faq")!)
            }

            Label(model.connectionStatus.rawValue, systemImage: model.connectionStatus == .connected ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
            if let detail = message ?? model.marketDataMessage {
                Text(detail).font(.appArialBold(10)).foregroundStyle(.red)
            }

            Text("Price alerts only. This app does not connect to brokerage orders or place trades.")
                .font(.appArialBold(10)).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(mode == "mock" ? "Use Mock Data" : "Save & Connect") { saveAndConnect() }
                    .buttonStyle(.borderedProminent).tint(AppTheme.accent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 500)
        .background(TechGridBackground())
        .preferredColorScheme(.dark)
    }

    private func saveAndConnect() {
        if mode == "mock" {
            model.useMockData()
            message = "Using offline Mock Data."
            dismiss()
            return
        }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !apiSecret.isEmpty else {
            message = "Enter both Alpaca API credentials."
            return
        }
        do {
            try KeychainService.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), account: "apiKey")
            try KeychainService.save(apiSecret, account: "apiSecret")
            guard let feed = AlpacaFeed(rawValue: mode) else { return }
            model.useAlpaca(key: apiKey.trimmingCharacters(in: .whitespacesAndNewlines), secret: apiSecret, feed: feed)
            dismiss()
        } catch {
            message = "Credentials could not be saved in Keychain."
        }
    }
}
