import SwiftUI

/// The settings screen. Export, import, delete and clipboard reads are all
/// actions, so nothing here reaches for a store or the pasteboard directly.
public struct SettingsListView: View {
    private let state: SettingsState
    @Binding private var brightnessBoost: Bool
    /// The import result to show in an alert. A resource, not a `String`, so
    /// the view resolves it in its own locale.
    @Binding private var message: LocalizedStringResource?
    private let actions: SettingsActions

    @State private var showDeleteConfirmation = false
    @State private var showImportSheet = false
    @State private var importText = ""
    @Environment(\.accessibilityAnnouncer) private var announcer
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(
        state: SettingsState,
        brightnessBoost: Binding<Bool>,
        message: Binding<LocalizedStringResource?> = .constant(nil),
        actions: SettingsActions = SettingsActions()
    ) {
        self.state = state
        _brightnessBoost = brightnessBoost
        _message = message
        self.actions = actions
    }

    public var body: some View {
        List {
            Section {
                if let version = state.appVersion, let build = state.appBuild {
                    HStack {
                        Text("Version", comment: "Settings row label for the app's version number.")
                            .foregroundColor(.primaryText)
                        Spacer()
                        Text("\(version) (\(build))", comment: "The app's version and then its build number, as in “1.1 (42)”.")
                            .foregroundColor(.secondaryText)
                            .readsLeftToRight()
                    }
                    // "Version, 1.1 (42)" as one element, not two.
                    .accessibilityElement(children: .combine)
                }

                if let url = state.authorURL {
                    Link(destination: url) {
                        HStack {
                            Text(
                                "Created by \(state.authorName)",
                                comment: "Settings row that opens the author's website. The argument is the author's name."
                            )
                            .foregroundColor(.primaryText)
                            Spacer()
                            // The link trait and the hint say where it goes; the
                            // arrow says it again for sighted users only.
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.accent)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint(
                        Text("Opens in your web browser", comment: "VoiceOver hint for the Settings row that opens the author's website.")
                    )
                }
            }

            Section {
                // The explanation is the switch's subtitle, so VoiceOver reads it
                // with the switch it explains.
                Toggle(isOn: $brightnessBoost) {
                    Text(
                        "Brightness Boost",
                        comment: "Settings switch for the feature that turns the screen up while a card is shown, so scanners can read its barcode."
                    )
                    Text(
                        "Boosts brightness when viewing card to improve scannability",
                        comment: "Explains the Brightness Boost switch above it in Settings."
                    )
                    .foregroundStyle(Color.secondaryText)
                }
                .tint(.accent)
                .accessibilityIdentifier("brightnessBoostToggle")
            } header: {
                Text("Display", comment: "Settings section heading for how cards are displayed.")
                    .foregroundStyle(Color.secondaryText)
            }

            Section {
                Button(action: actions.exportCards) {
                    Text("Export as JSON", comment: "Settings button that shares all cards as a JSON file. JSON is a file format; keep the name.")
                }
                .foregroundColor(.accent)
                .accessibilityIdentifier("exportJSONButton")

                Button {
                    showImportSheet = true
                } label: {
                    Text("Import JSON", comment: "Settings button that opens a sheet for pasting cards exported as JSON.")
                }
                .foregroundColor(.accent)
                .accessibilityIdentifier("importJSONButton")

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Text("Delete All Cards", comment: "Settings button that deletes every card after asking for confirmation.")
                        .foregroundStyle(Color.destructive)
                }
                .disabled(state.cardCount == 0)
                .accessibilityIdentifier("deleteAllCardsButton")
            } header: {
                Text("Data", comment: "Settings section heading for exporting, importing and deleting cards.")
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        // White cells on a white screen: with Increase Contrast the list keeps
        // the grouped background, so each cell has an edge.
        .scrollContentBackground(colorSchemeContrast == .increased ? .visible : .hidden)
        .background(Color.primaryBackground)
        .navigationTitle(Text("Settings", comment: "Title of the Settings screen."))
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
        .confirmationDialog(
            Text("Delete All Cards", comment: "Title of the dialog that asks the user to confirm deleting every card."),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                actions.deleteAllCards()
                announcer.announce(Announcements.allCardsDeleted)
            } label: {
                Text("Delete All", comment: "Destructive button in the delete-all dialog that deletes every card.")
            }
            Button(role: .cancel) {} label: {
                Text("Cancel", comment: "Button in the delete-all dialog that keeps the cards.")
            }
        } message: {
            Text(Self.deleteAllMessage(cardCount: state.cardCount))
        }
        .alert(
            Text("Import Result", comment: "Title of the alert shown after importing cards from JSON, whether it worked or not."),
            isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
        ) {
            Button {
                message = nil
            } label: {
                Text("OK", comment: "Dismisses the import result alert.")
            }
        } message: {
            if let message {
                Text(message)
            }
        }
    }

    /// The delete-all dialog's message, with a plural form for each count.
    static func deleteAllMessage(cardCount: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "This will permanently delete all \(cardCount) cards. This action cannot be undone.",
            comment: "Message in the delete-all dialog. The argument is how many cards there are, always at least one."
        )
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
                    .readsLeftToRight()
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    // Outside readsLeftToRight(), so the prompt follows the language.
                    .overlay(alignment: .topLeading) {
                        if importText.isEmpty {
                            Text(
                                "Paste exported JSON here",
                                comment: "Prompt in the empty text box of the import sheet. JSON is a file format; keep the name."
                            )
                                .foregroundStyle(Color.secondaryText)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel(
                        Text("JSON to import", comment: "VoiceOver label for the text box in the import sheet. JSON is a file format; keep the name.")
                    )
                    .accessibilityIdentifier("importTextEditor")
                    .padding()

                Button {
                    if let clipboard = readClipboard() {
                        importText = clipboard
                    }
                } label: {
                    Text("Paste from Clipboard", comment: "Button in the import sheet that fills the text box with what was last copied.")
                }
                // Plain accent text: on the bordered style's pink wash the accent
                // falls to 4:1.
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accent)
                .frame(minHeight: 44)
                .accessibilityIdentifier("pasteFromClipboardButton")
                .padding()
            }
            .navigationTitle(Text("Import JSON", comment: "Title of the sheet for pasting cards exported as JSON."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Closes the import sheet without importing.")
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onImport) {
                        Text("Import", comment: "Toolbar button in the import sheet that adds the pasted cards. A verb.")
                    }
                    .disabled(importText.isEmpty)
                    // Command-Return, as Return types a new line in the JSON.
                    .keyboardShortcut(.return, modifiers: .command)
                    .accessibilityIdentifier("importButton")
                }
            }
        }
    }
}
