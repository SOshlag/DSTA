import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ManagementView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var isAddingAlert = false
    @State private var isShowingMarketDataSettings = false
    @State private var exportMessage: String?

    private var preferredWindowHeight: CGFloat {
        guard !model.store.alerts.isEmpty else { return 260 }
        return min(680, max(270, 202 + CGFloat(model.store.alerts.count) * 28))
    }

    var body: some View {
        GeometryReader { geometry in
            let compactHeader = geometry.size.width < 850
            let compactTable = geometry.size.width < 600
            ZStack(alignment: .topLeading) {
                TechGridBackground().ignoresSafeArea()
                VStack(alignment: .leading, spacing: compactHeader ? 12 : 16) {
                    header(compact: compactHeader)
                    AlertTableView(compact: compactTable).appCard()
                    footer(compact: compactHeader)
                }
                .padding(compactHeader ? 12 : 20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                HStack(spacing: 0) {
                    HorizontalWindowResizeHandle(edge: .left)
                        .frame(width: 8)
                        .frame(maxHeight: .infinity)
                    Spacer(minLength: 0)
                    HorizontalWindowResizeHandle(edge: .right)
                        .frame(width: 8)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(minWidth: 560, minHeight: 260)
        .preferredColorScheme(.dark)
        .font(.appArialBold(12))
        .background(WindowHeightController(height: preferredWindowHeight))
        .sheet(isPresented: $isAddingAlert) {
            AlertFormView().environmentObject(model)
        }
        .sheet(isPresented: $isShowingMarketDataSettings) {
            MarketDataSettingsView().environmentObject(model)
        }
    }

    @ViewBuilder
    private func header(compact: Bool) -> some View {
        if compact {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    appIcon(size: 36)
                    Text("STOCK ALERTS").font(.appArialBold(18)).tracking(1.2).foregroundStyle(AppTheme.ink)
                    Spacer()
                    connectionPill
                }
                HStack(spacing: 6) {
                    if model.hasTriggeredAlert {
                        Button("Reset") { model.resetAllTriggered() }.tint(AppTheme.buy)
                    }
                    Button { isShowingMarketDataSettings = true } label: {
                        Label("Data", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    Button { exportAlerts() } label: {
                        Label("CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.store.alerts.isEmpty)
                    Spacer()
                    Button { isAddingAlert = true } label: {
                        Label("New", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent).tint(AppTheme.accent)
                }
            }
        } else {
            HStack {
                appIcon(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("STOCK ALERTS").font(.appArialBold(22)).tracking(1.5).foregroundStyle(AppTheme.ink)
                    HStack(spacing: 5) {
                        Circle().fill(AppTheme.buy).frame(width: 5, height: 5)
                        Text("LIVE MARKET MONITOR  •  COMPLETED TRADES")
                    }
                    .font(.appArialBold(9)).tracking(0.7).foregroundStyle(AppTheme.muted)
                }.fixedSize(horizontal: true, vertical: false)
                Spacer()
                connectionPill
                if model.hasTriggeredAlert {
                    Button("Reset Triggered") { model.resetAllTriggered() }.tint(AppTheme.buy)
                }
                Button { isShowingMarketDataSettings = true } label: {
                    Label("Data", systemImage: "antenna.radiowaves.left.and.right")
                }
                Button { exportAlerts() } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(model.store.alerts.isEmpty)
                Button { isAddingAlert = true } label: {
                    Label("New Alert", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent).tint(AppTheme.accent)
            }
        }
    }

    private func appIcon(size: CGFloat) -> some View {
        Image(systemName: "chart.line.uptrend.xyaxis")
            .font(.system(size: size * 0.48, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [AppTheme.cyan, AppTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            )
            .shadow(color: AppTheme.accent.opacity(0.38), radius: 10, y: 4)
    }

    @ViewBuilder
    private func footer(compact: Bool) -> some View {
        if compact {
            Label(model.marketData.feedName, systemImage: "dot.radiowaves.left.and.right")
                .lineLimit(1)
        } else {
            HStack {
                Label(model.marketData.feedName, systemImage: "dot.radiowaves.left.and.right")
                Spacer()
                Text("Alerts use the latest completed trade only. Triggering does not guarantee a brokerage fill.")
            }
        }
        if let message = model.marketDataMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.sell).lineLimit(2)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(AppTheme.sell.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        if let exportMessage {
            Label(exportMessage, systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.buy).lineLimit(2)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(AppTheme.buy.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func exportAlerts() {
        let panel = NSSavePanel()
        panel.title = "Export Tracked Stock Alerts"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "Stock Alerts \(Self.exportDate.string(from: Date())).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try AlertCSVExporter.data(for: model.store.alerts).write(to: url, options: .atomic)
            exportMessage = "Exported \(model.store.alerts.count) alert\(model.store.alerts.count == 1 ? "" : "s") to \(url.lastPathComponent)."
        } catch {
            exportMessage = nil
            let alert = NSAlert(error: error)
            alert.messageText = "Stock Alerts Could Not Export the CSV"
            alert.runModal()
        }
    }

    private static let exportDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var connectionPill: some View {
        let connected = model.connectionStatus == .connected
        return Label(model.connectionStatus.rawValue, systemImage: connected ? "checkmark.circle.fill" : "wifi.slash")
            .font(.appArialBold(10))
            .foregroundStyle(connected ? AppTheme.buy : AppTheme.muted)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background((connected ? AppTheme.buy : AppTheme.muted).opacity(0.11), in: Capsule())
            .overlay(Capsule().stroke((connected ? AppTheme.buy : AppTheme.muted).opacity(0.28)))
    }
}

private struct HorizontalWindowResizeHandle: NSViewRepresentable {
    enum Edge { case left, right }
    let edge: Edge

    func makeNSView(context: Context) -> ResizeHandleView {
        ResizeHandleView(edge: edge)
    }

    func updateNSView(_ view: ResizeHandleView, context: Context) {
        view.edge = edge
        view.window?.invalidateCursorRects(for: view)
    }

    final class ResizeHandleView: NSView {
        var edge: Edge
        private var startingWindowFrame: NSRect?
        private var startingMouseLocation: NSPoint?
        private var trackingArea: NSTrackingArea?

        init(edge: Edge) {
            self.edge = edge
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override var acceptsFirstResponder: Bool { true }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea { removeTrackingArea(trackingArea) }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .cursorUpdate, .mouseEnteredAndExited, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }

        override func cursorUpdate(with event: NSEvent) {
            NSCursor.resizeLeftRight.set()
        }

        override func mouseEntered(with event: NSEvent) {
            NSCursor.resizeLeftRight.set()
        }

        override func mouseExited(with event: NSEvent) {
            NSCursor.arrow.set()
        }

        override func mouseDown(with event: NSEvent) {
            startingWindowFrame = window?.frame
            startingMouseLocation = NSEvent.mouseLocation
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window, let startingWindowFrame, let startingMouseLocation else { return }
            let delta = NSEvent.mouseLocation.x - startingMouseLocation.x
            let minimumWidth = window.minSize.width
            let maximumWidth = window.maxSize.width > 0 ? window.maxSize.width : .greatestFiniteMagnitude
            var frame = startingWindowFrame

            switch edge {
            case .left:
                frame.size.width = min(max(startingWindowFrame.width - delta, minimumWidth), maximumWidth)
                frame.origin.x = startingWindowFrame.maxX - frame.width
            case .right:
                frame.size.width = min(max(startingWindowFrame.width + delta, minimumWidth), maximumWidth)
            }
            window.setFrame(frame, display: true)
        }

        override func mouseUp(with event: NSEvent) {
            startingWindowFrame = nil
            startingMouseLocation = nil
        }
    }
}

private struct WindowHeightController: NSViewRepresentable {
    let height: CGFloat

    final class Coordinator { var lastAppliedHeight: CGFloat? }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        guard context.coordinator.lastAppliedHeight != height else { return }
        context.coordinator.lastAppliedHeight = height
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            let current = window.contentLayoutRect.height
            guard abs(current - height) > 1 else { return }
            var frame = window.frame
            let difference = height - current
            frame.origin.y -= difference
            frame.size.height += difference
            window.setFrame(frame, display: true, animate: true)
        }
    }
}

private struct AlertTableView: View {
    @EnvironmentObject private var model: AppViewModel
    let compact: Bool
    @State private var selection: StockAlert.ID?
    @State private var editingAlert: StockAlert?
    @State private var sortOrder: [KeyPathComparator<StockAlert>] = []

    private var rows: [StockAlert] {
        guard !sortOrder.isEmpty else {
            return model.store.alerts.sorted { $0.dateCreated > $1.dateCreated }
        }
        return model.store.alerts.sorted(using: sortOrder)
    }

    var body: some View {
        Group {
            if rows.isEmpty {
                emptyState
            } else {
                alertTable
            }
        }
        .padding(8)
        .sheet(item: $editingAlert) { alert in
            EditAlertSheet(alert: alert)
                .environmentObject(model)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.badge")
                .font(.system(size: 27, weight: .semibold)).foregroundStyle(AppTheme.accent)
                .frame(width: 54, height: 54)
                .background(AppTheme.accent.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(AppTheme.accent.opacity(0.30)))
            Text("No alerts yet").font(.appArialBold(16)).foregroundStyle(AppTheme.ink)
            Text("Create a price alert to begin monitoring completed trades.")
                .font(.appArialBold(11)).foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 22)
    }

    @ViewBuilder
    private var alertTable: some View {
        if compact {
            compactAlertList
        } else {
            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                alertColumns
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.ink)
            .frame(minHeight: 74, idealHeight: tableHeight, maxHeight: tableHeight)
        }
    }

    private var tableHeight: CGFloat { min(478, 30 + CGFloat(rows.count) * 28) }

    private var compactAlertList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TRACKED STOCKS").font(.appArialBold(9)).tracking(1).foregroundStyle(AppTheme.muted)
                Spacer()
                compactSortMenu
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(rows) { alert in
                        compactCard(for: alert)
                    }
                }
            }
            .frame(maxHeight: 478)
        }
    }

    private var compactSortMenu: some View {
        Menu {
            Button("Symbol — A to Z") { sortOrder = [KeyPathComparator(\StockAlert.symbol, order: .forward)] }
            Button("Symbol — Z to A") { sortOrder = [KeyPathComparator(\StockAlert.symbol, order: .reverse)] }
            Divider()
            Button("Type") { sortOrder = [KeyPathComparator(\StockAlert.sortableTypeTitle)] }
            Button("Status") { sortOrder = [KeyPathComparator(\StockAlert.sortableStatusTitle)] }
            Button("Note") { sortOrder = [KeyPathComparator(\StockAlert.sortableNote)] }
            Divider()
            Button("Newest First") { sortOrder = [] }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func compactCard(for alert: StockAlert) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(alert.symbol)
                    .font(.appArialBold(18)).tracking(1.1).foregroundStyle(AppTheme.ink)
                Spacer()
                Label(statusTitle(alert.status), systemImage: statusIcon(alert.status))
                    .font(.appArialBold(10)).foregroundStyle(statusColor(alert))
                alertActions(for: alert)
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 10) {
                GridRow {
                    compactMetric("TYPE", alert.alertType.title, color: alert.alertType.isBuy ? AppTheme.buy : AppTheme.sell)
                    compactMetric("TARGET", AppFormatters.money(alert.targetPrice))
                }
                GridRow {
                    compactMetric("LAST TRADE", alert.lastTradePrice.map(AppFormatters.money) ?? "Waiting…", color: alert.lastTradePrice == nil ? AppTheme.muted : AppTheme.cyan)
                    compactMetric("DISTANCE", distanceText(alert), color: AppTheme.muted)
                }
            }
            if let note = alert.note, !note.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NOTE").font(.appArialBold(8)).tracking(0.8).foregroundStyle(AppTheme.muted)
                    Text(note).font(.appArialBold(11)).foregroundStyle(AppTheme.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(AppTheme.inputSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { editingAlert = alert }
    }

    private func compactMetric(_ title: String, _ value: String, color: Color = AppTheme.ink) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.appArialBold(8)).tracking(0.8).foregroundStyle(AppTheme.muted)
            Text(value).font(.appArialBold(11)).foregroundStyle(color).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @TableColumnBuilder<StockAlert, KeyPathComparator<StockAlert>>
    private var alertColumns: some TableColumnContent<StockAlert, KeyPathComparator<StockAlert>> {
        TableColumn("SYMBOL", value: \.symbol) { alert in
                        Text(alert.symbol).font(.appArialBold(14)).tracking(1.0).foregroundStyle(AppTheme.ink)
                            .onTapGesture(count: 2) { editingAlert = alert }
                    }.width(min: 60, ideal: 75, max: 90)
                    TableColumn("TYPE", value: \.sortableTypeTitle) { alert in
                        Label(alert.alertType.title, systemImage: alert.alertType.directionSystemImage)
                            .foregroundStyle(alert.alertType.isBuy ? AppTheme.buy : AppTheme.sell)
                    }.width(min: 90, ideal: 105, max: 125)
                    TableColumn("TARGET") { alert in
                        Text(AppFormatters.money(alert.targetPrice)).monospacedDigit().foregroundStyle(AppTheme.ink)
                    }.width(min: 75, ideal: 90, max: 105)
                    TableColumn("LAST TRADE") { alert in
                        Text(alert.lastTradePrice.map(AppFormatters.money) ?? "Waiting…")
                            .monospacedDigit().foregroundStyle(alert.lastTradePrice == nil ? AppTheme.muted : AppTheme.cyan)
                    }.width(min: 82, ideal: 98, max: 115)
                    TableColumn("DISTANCE") { alert in
                        Text(distanceText(alert)).lineLimit(1).monospacedDigit().foregroundStyle(AppTheme.muted)
                    }.width(min: 90, ideal: 110, max: 130)
                    TableColumn("STATUS", value: \.sortableStatusTitle) { alert in
                        Label(statusTitle(alert.status), systemImage: statusIcon(alert.status))
                            .foregroundStyle(statusColor(alert))
                    }.width(min: 90, ideal: 105, max: 120)
                    TableColumn("NOTE", value: \.sortableNote) { alert in
                        if let note = alert.note, !note.isEmpty {
                            Text(note).lineLimit(1).truncationMode(.tail).help(note).foregroundStyle(AppTheme.muted)
                        }
                    }.width(min: 80, ideal: 120, max: 150)
                    actionColumn
    }

    private var actionColumn: TableColumn<StockAlert, Never, some View, Text> {
        TableColumn("") { alert in
            alertActions(for: alert)
        }.width(38)
    }

    private func alertActions(for alert: StockAlert) -> some View {
        Menu {
            Button("Edit") { editingAlert = alert }
            if alert.status == .triggered {
                Button("Reset") { model.reset(alert) }
            } else {
                Button(alert.status == .paused ? "Resume" : "Pause") { model.togglePause(alert) }
            }
            Divider()
            Button("Delete", role: .destructive) { model.delete(alert) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func distanceText(_ alert: StockAlert) -> String {
        guard let price = alert.lastTradePrice else { return "—" }
        let delta = price - alert.targetPrice
        let reached = alert.alertType.isReached(price: price, target: alert.targetPrice)
        if reached { return "Target reached" }
        let absolute = delta < 0 ? -delta : delta
        return "\(AppFormatters.money(absolute)) \(delta >= 0 ? "above" : "below")"
    }
    private func statusTitle(_ status: AlertStatus) -> String {
        switch status {
        case .active: "Monitoring"
        case .paused: "Paused"
        case .triggered: "Triggered"
        case .waitingForTrade: "Waiting"
        case .dataUnavailable: "Data Unavailable"
        }
    }
    private func statusIcon(_ status: AlertStatus) -> String {
        switch status {
        case .active: "checkmark.circle.fill"
        case .paused: "pause.circle.fill"
        case .triggered: "bell.fill"
        case .waitingForTrade: "clock.fill"
        case .dataUnavailable: "wifi.slash"
        }
    }
    private func statusColor(_ alert: StockAlert) -> Color {
        switch alert.status {
        case .triggered: alert.alertType.isBuy ? AppTheme.buy : AppTheme.sell
        case .paused: .orange
        case .dataUnavailable: AppTheme.sell
        case .active: AppTheme.accent
        case .waitingForTrade: .secondary
        }
    }
}

private struct EditAlertSheet: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let alert: StockAlert
    @State private var type: AlertType
    @State private var target: String
    @State private var note: String
    @State private var error: String?

    init(alert: StockAlert) {
        self.alert = alert
        _type = State(initialValue: alert.alertType)
        _target = State(initialValue: NSDecimalNumber(decimal: alert.targetPrice).stringValue)
        _note = State(initialValue: alert.note ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Price Alert").font(.appArialBold(20)).foregroundStyle(AppTheme.ink)
                    Text(alert.symbol).font(.appArialBold(11)).tracking(1.2).foregroundStyle(AppTheme.muted)
                }
            }
            Text("ALERT TYPE").font(.appArialBold(9)).tracking(1).foregroundStyle(AppTheme.muted)
            Picker("Type", selection: $type) { ForEach(AlertType.allCases) { Text($0.title).tag($0) } }
                .labelsHidden().pickerStyle(.segmented).controlSize(.large)
            Text("TARGET PRICE").font(.appArialBold(9)).tracking(1).foregroundStyle(AppTheme.muted)
            TextField("Target Price", text: $target).textFieldStyle(.roundedBorder).controlSize(.large)
            Text("NOTE — OPTIONAL").font(.appArialBold(9)).tracking(1).foregroundStyle(AppTheme.muted)
            TextEditor(text: $note)
                .scrollContentBackground(.hidden)
                .padding(6).frame(height: 80)
                .background(AppTheme.inputSurface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border))
                .onChange(of: note) { value in if value.count > 400 { note = String(value.prefix(400)) } }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save Changes") {
                    error = model.edit(alert, type: type, targetText: target, noteText: note)
                    if error == nil { dismiss() }
                }.buttonStyle(.borderedProminent).tint(AppTheme.accent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 450)
        .background(TechGridBackground())
        .preferredColorScheme(.dark)
    }
}

@MainActor
final class DesktopManagerWindowController {
    static let shared = DesktopManagerWindowController()
    private var window: NSWindow?
    private weak var model: AppViewModel?

    func show(model: AppViewModel) {
        self.model = model
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let initialHeight = model.store.alerts.isEmpty
            ? 260
            : min(680, max(270, 202 + CGFloat(model.store.alerts.count) * 28))
        let availableWidth = NSScreen.main?.visibleFrame.width ?? 900
        let initialWidth = min(900, max(560, availableWidth - 32))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 260)
        window.title = "Stock Alerts"
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .line
        window.isOpaque = true
        window.backgroundColor = NSColor(srgbRed: 0.035, green: 0.052, blue: 0.085, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.center()
        window.contentView = NSHostingView(rootView: ManagementView().environmentObject(model))
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reopen() {
        guard let model else { return }
        show(model: model)
    }
}
