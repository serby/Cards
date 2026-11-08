import SwiftUI

/// The settings about where the cards and the app's data go: iCloud Sync and
/// deleting the cards in iCloud (DATA-8, DATA-9), Share Diagnostics (PLAT-11)
/// and the open source software the app is built with (PLAT-12).
extension SettingsListView {
    var iCloudSection: some View {
        Section {
            switchRow(
                Text(
                    "iCloud Sync",
                    comment: "Settings switch that syncs the cards through the user's iCloud account. iCloud is Apple's service; keep the name."
                ),
                subtitle: Text(
                    "Keeps your cards in your iCloud account, so they are on all your devices. Turn it off to keep them on this device only.",
                    comment: "Under the iCloud Sync switch in Settings, saying what it does when it is on and when it is off."
                ),
                isOn: $syncsWithICloud,
                identifier: "iCloudSyncToggle"
            )
            if !syncsWithICloud {
                Button(role: .destructive) {
                    showICloudDeleteConfirmation = true
                } label: {
                    Text(
                        "Delete Cards from iCloud",
                        comment: "Settings button, shown with iCloud Sync off, that deletes the cards in iCloud after asking."
                    )
                    .foregroundStyle(Color.destructive)
                }
                .disabled(state.iCloudDeletion == .deleting)
                .accessibilityIdentifier("deleteICloudCardsButton")
                // On the button, so on iPad the dialog's popover points at it.
                .confirmationDialog(
                    Text("Delete Cards from iCloud", comment: "Title of the dialog that asks the user to confirm deleting their cards from iCloud."),
                    isPresented: $showICloudDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(role: .destructive, action: actions.deleteICloudCards) {
                        Text("Delete from iCloud", comment: "Destructive button in the dialog that deletes the user's cards from iCloud.")
                    }
                    .accessibilityIdentifier("confirmDeleteICloudCardsButton")
                    Button(role: .cancel) {} label: {
                        Text("Cancel", comment: "Button in the delete-from-iCloud dialog that keeps the cards in iCloud.")
                    }
                } message: {
                    Text(
                        "This deletes your cards from iCloud. The cards on this device are kept.",
                        comment: "Message in the dialog that asks the user to confirm deleting their cards from iCloud."
                    )
                }
                iCloudDeletionCaption
            }
        } header: {
            Text("iCloud", comment: "Settings section heading for syncing the cards through iCloud. iCloud is Apple's service; keep the name.")
                .foregroundStyle(Color.secondaryText)
                .accessibilityIdentifier("iCloudSectionHeader")
        }
    }

    /// What deleting the cards in iCloud does, or how it went, under the button.
    /// VoiceOver says how it went when it ends, as focus stays on the button.
    private var iCloudDeletionCaption: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if state.iCloudDeletion == .deleting {
                ProgressView()
                    .accessibilityHidden(true)
            }
            Text(Self.iCloudDeletionCaption(state.iCloudDeletion))
        }
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("iCloudDeletionCaption")
        .onChange(of: state.iCloudDeletion) { _, deletion in
            if deletion == .deleted || deletion == .failed {
                announcer.announce(String(localized: Self.iCloudDeletionCaption(deletion)))
            }
        }
    }

    /// The caption under Delete Cards from iCloud for `deletion`.
    static func iCloudDeletionCaption(_ deletion: ICloudDeletion) -> LocalizedStringResource {
        switch deletion {
        case .notAsked:
            LocalizedStringResource(
                "Your cards stay in iCloud until you delete them there.",
                comment: "Under Delete Cards from iCloud in Settings, with iCloud Sync off, before anything has been deleted."
            )
        case .deleting:
            LocalizedStringResource(
                "Deleting your cards from iCloud…",
                comment: "Under Delete Cards from iCloud in Settings, while the cards are being deleted from iCloud."
            )
        case .deleted:
            LocalizedStringResource(
                "Your cards are no longer in iCloud. A device that still has iCloud Sync on will upload its cards again.",
                comment: "Under Delete Cards from iCloud in Settings, once the cards have been deleted from iCloud. iCloud Sync is the switch above."
            )
        case .failed:
            LocalizedStringResource(
                "Your cards could not be deleted from iCloud. Check that you're signed in to iCloud and online, then try again.",
                comment: "Under Delete Cards from iCloud in Settings, when iCloud could not be reached or the user is not signed in to it."
            )
        }
    }

    var privacySection: some View {
        Section {
            switchRow(
                Text("Share Diagnostics", comment: "Settings switch that lets the app send its developer crash reports and performance data."),
                subtitle: Text(
                    """
                    Lets Card Barcodes send crash reports and performance data to its developer, to find and fix problems. \
                    Your cards and places are never included.
                    """,
                    comment: "Under the Share Diagnostics switch in Settings, saying what it allows. Card Barcodes is the app's name."
                ),
                isOn: $sharesDiagnostics,
                identifier: "shareDiagnosticsToggle"
            )
            Text(
                """
                iOS shares its own crash reports with app developers only when Share With App Developers is on, \
                in Privacy & Security > Analytics & Improvements in the Settings app. Card Barcodes can't change that setting.
                """,
                comment: """
                    Under the Share Diagnostics switch in Settings. Share With App Developers, Privacy & Security and \
                    Analytics & Improvements are the names of iOS's own settings; use their names in your language.
                    """
            )
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .accessibilityIdentifier("shareDiagnosticsFooter")
        } header: {
            Text("Privacy", comment: "Settings section heading for the Share Diagnostics switch.")
                .foregroundStyle(Color.secondaryText)
                .accessibilityIdentifier("privacySectionHeader")
        }
    }

    var acknowledgementsSection: some View {
        Section {
            ForEach(state.libraries) { library in
                NavigationLink {
                    OpenSourceLicenceView(library: library)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: library.name)
                            .foregroundStyle(Color.primaryText)
                        Text(verbatim: library.licenceName)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                .accessibilityIdentifier("libraryRow")
            }
        } header: {
            Text(
                "Acknowledgements",
                comment: "Settings section heading for the open source software the app is built with, each opening its licence."
            )
            .foregroundStyle(Color.secondaryText)
            .accessibilityIdentifier("acknowledgementsSectionHeader")
        } footer: {
            Text(
                "Card Barcodes is built with this open source software. Each row opens its licence.",
                comment: "Under the Acknowledgements section in Settings. Card Barcodes is the app's name."
            )
            .foregroundStyle(Color.secondaryText)
            .accessibilityIdentifier("acknowledgementsFooter")
        }
    }
}
