import SwiftUI
import UniformTypeIdentifiers

/// The settings screen. Export, import, delete and clipboard reads are all
/// actions, so nothing here reaches for a store, the pasteboard or a file directly.
public struct SettingsListView: View {
    let state: SettingsState
    @Binding private var brightnessBoost: Bool
    @Binding private var arrivalNotifications: Bool
    @Binding private var showsCardWhereYouAre: Bool
    @Binding private var distanceUnits: DistanceUnits
    /// Whether the cards sync through iCloud (DATA-8).
    @Binding var syncsWithICloud: Bool
    /// Whether the app may send its developer diagnostics (PLAT-11).
    @Binding var sharesDiagnostics: Bool
    /// The import result to show in an alert, already in the app's language.
    @Binding private var message: String?
    let actions: SettingsActions

    @State private var showDeleteConfirmation = false
    @State var showICloudDeleteConfirmation = false
    @State private var showImportSheet = false
    @State private var importText = ""
    @Environment(\.accessibilityAnnouncer) var announcer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Says what Automatic means, as "Automatic (Kilometres)".
    @Environment(\.locale) private var locale

    public init(
        state: SettingsState,
        brightnessBoost: Binding<Bool>,
        arrivalNotifications: Binding<Bool> = .constant(true),
        showsCardWhereYouAre: Binding<Bool> = .constant(false),
        distanceUnits: Binding<DistanceUnits> = .constant(.automatic),
        syncsWithICloud: Binding<Bool> = .constant(true),
        sharesDiagnostics: Binding<Bool> = .constant(true),
        message: Binding<String?> = .constant(nil),
        actions: SettingsActions = SettingsActions()
    ) {
        self.state = state
        _brightnessBoost = brightnessBoost
        _arrivalNotifications = arrivalNotifications
        _showsCardWhereYouAre = showsCardWhereYouAre
        _distanceUnits = distanceUnits
        _syncsWithICloud = syncsWithICloud
        _sharesDiagnostics = sharesDiagnostics
        _message = message
        self.actions = actions
    }

    public var body: some View {
        List {
            if !state.changelog.isEmpty {
                Section {
                    NavigationLink {
                        ChangelogView(versions: state.changelog)
                    } label: {
                        Text("What's New", comment: "Settings row that opens the list of what changed in each version of the app.")
                            .foregroundColor(.primaryText)
                    }
                    .accessibilityIdentifier("whatsNewRow")
                }
            }

            Section {
                switchRow(
                    Text(
                        "Brightness Boost",
                        comment: "Settings switch for the feature that turns the screen up while a card is shown, so scanners can read its barcode."
                    ),
                    subtitle: Text(
                        "Turns the screen up to full brightness while a card is open, so its barcode scans easily.",
                        comment: "Under the Brightness Boost switch in Settings, saying what the switch does when it is on."
                    ),
                    isOn: $brightnessBoost,
                    identifier: "brightnessBoostToggle"
                )
            } header: {
                Text("Display", comment: "Settings section heading for how cards are displayed.")
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("displaySectionHeader")
            }

            Section {
                switchRow(
                    Text("Arrival Notifications", comment: "Settings switch for the notification shown on arriving at one of a card's places."),
                    subtitle: Text(
                        """
                        Reminds you when you arrive at one of a card's places. \
                        To stop one card reminding you, turn off Notify When I Arrive when you edit it.
                        """,
                        comment: """
                        Under the Arrival Notifications switch in Settings, saying what it does. \
                        Notify When I Arrive is the switch of that name in the card form; use its translation.
                        """
                    ),
                    isOn: $arrivalNotifications,
                    identifier: "arrivalNotificationsToggle"
                )
                if arrivalNotifications && state.notificationsBlocked {
                    Button(action: actions.openNotificationSettings) {
                        Label(
                            LocalizedStringResource(
                                "Notifications are off for Card Barcodes. Turn them on in Settings.",
                                comment: """
                                Button under the Arrival Notifications switch, shown when the switch is on but iOS has notifications \
                                turned off for the app. It opens the app's page in the Settings app. Card Barcodes is the app's name.
                                """
                            ),
                            systemImage: "bell.slash"
                        )
                        .font(.callout)
                    }
                    .foregroundColor(.accent)
                    .accessibilityIdentifier("openNotificationSettingsButton")
                }
                switchRow(
                    Text("Show Card Where I Am", comment: "Settings switch that puts the card for where the user is first in the card list."),
                    subtitle: Text(
                        "Shows the card for where you are at the top of your cards.",
                        comment: "Under the Show Card Where I Am switch in Settings, saying what it does when it is on."
                    ),
                    isOn: $showsCardWhereYouAre,
                    identifier: "showsCardWhereYouAreToggle"
                )
                distanceUnitsMenu
                Text(
                    "Automatic follows the measurement system in Language & Region in the Settings app.",
                    comment: """
                        Under the Distances menu in Settings. Language & Region is the name of iOS's own settings screen; \
                        use its name in your language.
                        """
                )
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .accessibilityIdentifier("distanceUnitsFooter")
            } header: {
                Text("Locations", comment: "Settings section heading for the switches about arrival notifications and the card for where you are.")
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("locationsSectionHeader")
            }

            iCloudSection

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
                // On the button, so on iPad the dialog's popover points at it.
                // On the whole list it was anchored at the top of the screen,
                // squashed under the tab bar, with its warning cut off.
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
                    .accessibilityIdentifier("confirmDeleteAllButton")
                    Button(role: .cancel) {} label: {
                        Text("Cancel", comment: "Button in the delete-all dialog that keeps the cards.")
                    }
                } message: {
                    Text(Self.deleteAllMessage(cardCount: state.cardCount))
                }
            } header: {
                Text("Data", comment: "Settings section heading for exporting, importing and deleting cards.")
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("dataSectionHeader")
            }

            privacySection
            acknowledgementsSection

            Section {
                if let version = state.appVersion, let build = state.appBuild {
                    // Side by side, or the number under its label at accessibility
                    // sizes, where both wrapped ("Versio- / n", "1.1 / (30)").
                    rowLayout {
                        Text("Version", comment: "Settings row label for the app's version number.")
                            .foregroundColor(.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(version) (\(build))", comment: "The app's version and then its build number, as in “1.1 (42)”.")
                            .foregroundColor(.secondaryText)
                            .readsLeftToRight()
                    }
                    // "Version, 1.1 (42)" as one element, not two.
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("versionRow")
                }

                if let url = state.authorURL {
                    Link(destination: url) {
                        HStack {
                            // A name breaks between lines as a whole, not between
                            // its words ("Paul / Serby").
                            Text(
                                "Created by \(state.authorName.replacingOccurrences(of: " ", with: "\u{00A0}"))",
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
                    .accessibilityIdentifier("authorLink")
                }
            }
        }
        // The system's grouped grey behind white rows, so each section stands
        // apart and the long screen reads as groups.
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Settings", comment: "Title of the Settings screen."))
        .sheet(isPresented: $showImportSheet) {
            ImportCardsView(
                importText: $importText,
                readClipboard: actions.readClipboard,
                onImport: {
                    actions.importCards(importText)
                    showImportSheet = false
                    importText = ""
                },
                onChooseFile: { choice in
                    actions.importFile(choice)
                    showImportSheet = false
                    importText = ""
                }
            )
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

extension SettingsListView {
    /// A label and its value or control side by side, or stacked at
    /// accessibility text sizes. No Spacer inside: the label fills the row.
    var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
    }

    /// The Distances menu: its title and the units side by side, or the units
    /// under the title at accessibility sizes, wrapping. The system's menu
    /// picker cut its value off there ("Auto…Miles)" on iOS 26.5), so this is
    /// a menu of the same choices with a label of its own. VoiceOver reads it
    /// as it read the picker: the title, then the units as its value.
    var distanceUnitsMenu: some View {
        let title = Text(
            "Distances",
            comment: "Settings menu for the units distances and radii are shown in: Automatic, Kilometres or Miles."
        )
        let value = Text(distanceUnits.title(for: locale))
        return Menu {
            Picker(selection: $distanceUnits) {
                ForEach(DistanceUnits.allCases) { units in
                    Text(units.title(for: locale))
                        .tag(units)
                }
            } label: {
                title
            }
        } label: {
            rowLayout {
                title
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    value
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                }
                .foregroundStyle(Color.accent)
            }
        }
        .tint(.accent)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityIdentifier("distanceUnitsPicker")
    }

    /// A switch with a line or two under its title saying what it does. Side by
    /// side, or the switch under its text at accessibility sizes, where beside it
    /// the text had a third of the row and ran a word or two to a line. The row
    /// draws the text in both layouts, so nothing is swapped as the text size
    /// changes, and hides it from VoiceOver, which reads the explanation as the
    /// switch's subtitle, with the switch it explains.
    func switchRow(_ title: Text, subtitle: Text, isOn: Binding<Bool>, identifier: String) -> some View {
        rowLayout {
            VStack(alignment: .leading, spacing: 2) {
                title
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
            Toggle(isOn: isOn) {
                title
                subtitle
                    .foregroundStyle(Color.secondaryText)
            }
            .labelsHidden()
            .tint(.accent)
            .accessibilityIdentifier(identifier)
        }
    }
}

#if DEBUG
#Preview("With cards") {
    @Previewable @State var boost = true
    NavigationStack {
        SettingsListView(state: .sample, brightnessBoost: $boost)
    }
}

#Preview("Notifications blocked") {
    @Previewable @State var arrivals = true
    NavigationStack {
        SettingsListView(state: .withNotificationsBlocked, brightnessBoost: .constant(true), arrivalNotifications: $arrivals)
    }
}

#Preview("No cards") {
    @Previewable @State var boost = false
    NavigationStack {
        SettingsListView(state: .noCards, brightnessBoost: $boost)
    }
}

#Preview("iCloud Sync off") {
    @Previewable @State var syncs = false
    NavigationStack {
        SettingsListView(state: .sample, brightnessBoost: .constant(true), syncsWithICloud: $syncs)
    }
}

#Preview("Distances in miles") {
    @Previewable @State var units = DistanceUnits.miles
    NavigationStack {
        SettingsListView(state: .sample, brightnessBoost: .constant(true), distanceUnits: $units)
    }
}
#endif
