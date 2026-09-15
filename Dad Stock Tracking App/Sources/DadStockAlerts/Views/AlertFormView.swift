import SwiftUI

struct AlertFormView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @StateObject private var symbolSearch = AlpacaAssetSearchService()
    @State private var symbol = ""
    @State private var type: AlertType = .buyBelow
    @State private var target = ""
    @State private var note = ""
    @State private var error: String?

    private enum Field { case symbol, target }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Price Alert").font(.appArialBold(21)).foregroundStyle(AppTheme.ink)
                    Text("Choose a symbol, direction, and target.").font(.appArialBold(10)).foregroundStyle(AppTheme.muted)
                }
            }

            labeled("Stock Symbol") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Type a ticker or company name", text: $symbol)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .focused($focusedField, equals: .symbol)
                        .onChange(of: symbol) { symbolSearch.update(query: $0) }
                    if symbolSearch.isLoading {
                        Label("Loading stock directory…", systemImage: "arrow.triangle.2.circlepath")
                            .font(.appArialBold(10)).foregroundStyle(.secondary)
                    }
                    if !symbolSearch.suggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(symbolSearch.suggestions) { suggestion in
                                Button {
                                    symbol = suggestion.symbol
                                    symbolSearch.clear()
                                    focusedField = .target
                                } label: {
                                    HStack(spacing: 9) {
                                        Text(suggestion.symbol).font(.appArialBold(12)).frame(width: 52, alignment: .leading)
                                        Text(suggestion.name).font(.appArialBold(11)).lineLimit(1)
                                        Spacer()
                                        Text(suggestion.exchange).font(.appArialBold(9)).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 9).padding(.vertical, 7)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if suggestion.id != symbolSearch.suggestions.last?.id { Divider() }
                            }
                        }
                        .background(AppTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border))
                        .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
                    } else if let message = symbolSearch.message {
                        Text(message).font(.appArialBold(10)).foregroundStyle(.secondary)
                    }
                }
            }
            labeled("Alert Type") {
                Picker("Alert Type", selection: $type) {
                    ForEach(AlertType.allCases) { Text($0.title).tag($0) }
                }.labelsHidden().pickerStyle(.segmented).controlSize(.large)
            }
            labeled("Target Price") {
                TextField("$185.00", text: $target)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .focused($focusedField, equals: .target)
            }
            labeled("Note — Optional") {
                VStack(alignment: .trailing, spacing: 3) {
                    TextEditor(text: $note)
                        .font(.appArialBold(12))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .frame(minHeight: 54, maxHeight: 76)
                        .background(AppTheme.inputSurface, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("Why are you watching this stock?")
                                    .font(.appArialBold(11)).foregroundStyle(.secondary)
                                    .padding(.horizontal, 11).padding(.vertical, 13)
                                    .allowsHitTesting(false)
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border))
                        .onChange(of: note) { value in if value.count > 400 { note = String(value.prefix(400)) } }
                    if note.count >= 350 { Text("\(note.count)/400").font(.appArialBold(9)).foregroundStyle(.secondary) }
                }
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.appArialBold(11))
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add Alert") { submit() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 450)
        .background(TechGridBackground())
        .preferredColorScheme(.dark)
        .onAppear { focusedField = .symbol }
    }

    private func submit() {
        error = model.add(symbol: symbol, type: type, targetText: target, noteText: note)
        if error == nil { dismiss() }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.appArialBold(9)).tracking(1.0).foregroundStyle(AppTheme.muted)
            content()
        }
    }
}
