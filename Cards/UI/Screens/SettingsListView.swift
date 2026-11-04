import SwiftUI

/// The settings screen. Export, import, delete and clipboard reads are all
/// actions, so nothing here reaches for a store or the pasteboard directly.
public struct SettingsListView: View {
    private let state: SettingsState
    @Binding private var brightnessBoost: Bool
    @Binding private var arrivalNotifications: Bool
    @Binding private var message: String?
    private let actions: SettingsActions

    @State private var showDeleteConfirmation = false
    @State private var showImportSheet = false
    @State private var importText = ""

    public init(
        state: SettingsState,
        brightnessBoost: Binding<Bool>,
        arrivalNotifications: Binding<Bool> = .constant(true),
        message: Binding<String?> = .constant(nil),
        actions: SettingsActions = SettingsActions()
    ) {
        self.state = state
        _brightnessBoost = brightnessBoost
        _arrivalNotifications = arrivalNotifications
        _message = message
        self.actions = actions
    }

    public var body: some View {
        List {
            Section {
                if let version = state.appVersion, let build = state.appBuild {
                    HStack {
                        Text("Version")
                            .foregroundColor(.primaryText)
                        Spacer()
                        Text("\(version) (\(build))")
                            .foregroundColor(.secondaryText)
                    }
                }

                if let url = state.authorURL {
                    Link(destination: url) {
                        HStack {
                            Text("Created by \(state.authorName)")
                                .foregroundColor(.primaryText)
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.accent)
                                .accessibilityLabel("External link")
                        }
                    }
                }
            }

            Section {
                Toggle("Brightness Boost", isOn: $brightnessBoost)
                    .tint(.accent)
                Text("Boosts brightness when viewing card to improve scannability")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            } header: {
                Text("Display")
                    .foregroundColor(.secondaryText)
            }

            Section {
                Toggle("Arrival Notifications", isOn: $arrivalNotifications)
                    .tint(.accent)
                    .accessibilityIdentifier("arrivalNotificationsToggle")
                Text("Shows a card's barcode on your Lock Screen when you arrive at one of its places")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
                if arrivalNotifications && state.notificationsBlocked {
                    Button(action: actions.openNotificationSettings) {
                        Label("Notifications are off for Card Barcodes. Turn them on in Settings.", systemImage: "bell.slash")
                            .font(.callout)
                    }
                    .foregroundColor(.accent)
                    .accessibilityIdentifier("openNotificationSettingsButton")
                }
            } header: {
                Text("Locations")
                    .foregroundColor(.secondaryText)
            }

            Section("Data") {
                Button("Export as JSON", action: actions.exportCards)
                    .foregroundColor(.accent)

                Button("Import JSON") {
                    showImportSheet = true
                }
                .foregroundColor(.accent)

                Button("Delete All Cards", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(state.cardCount == 0)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground)
        .navigationTitle("Settings")
        .sheet(isPresented: $showImportSheet) {
            ImportCardsView(
                importText: $importText,
                readClipboard: actions.readClipboard,
                onImport: {
                    actions.importCards(importText)
                    showImportSheet = false
                    importText = ""
                }
            )
        }
        .confirmationDialog("Delete All Cards", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete All", role: .destructive, action: actions.deleteAllCards)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(state.cardCount) cards. This action cannot be undone.")
        }
        .alert("Import Result", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

public struct ImportCardsView: View {
    @Binding private var importText: String
    private let readClipboard: () -> String?
    private let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        importText: Binding<String>,
        readClipboard: @escaping () -> String? = { nil },
        onImport: @escaping () -> Void
    ) {
        _importText = importText
        self.readClipboard = readClipboard
        self.onImport = onImport
    }

    public var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $importText)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()

                Button("Paste from Clipboard") {
                    if let clipboard = readClipboard() {
                        importText = clipboard
                    }
                }
                .buttonStyle(.bordered)
                .padding()
            }
            .navigationTitle("Import JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: onImport)
                        .disabled(importText.isEmpty)
                }
            }
        }
    }
}
