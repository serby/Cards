import SwiftUI

/// The settings about where the cards and the app's data go: iCloud Sync, how
/// it is going and deleting the cards in iCloud (DATA-8, DATA-10, DATA-9), Share Diagnostics (PLAT-11)
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
            if syncsWithICloud {
                iCloudSyncStatusRow
            } else {
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

    /// How iCloud Sync is going, under its switch while it is on (DATA-10): a
    /// symbol and a line for where it has got to, and what to do about it, or
    /// when it last synced. The time since then counts on while it shows.
    private var iCloudSyncStatusRow: some View {
        let status = state.iCloudSync
        // Centred on the line and its caption, as the symbol and the spinner are not text.
        return HStack(spacing: 12) {
            if status == .syncing || status == .checking {
                ProgressView()
                    .accessibilityHidden(true)
            } else {
                Image(systemName: Self.iCloudSyncSymbol(status))
                    .foregroundStyle(Self.iCloudSyncNeedsAttention(status) ? Color.destructive : Color.secondaryText)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.iCloudSyncTitle(status))
                TimelineView(.everyMinute) { _ in
                    if let detail = Self.iCloudSyncDetail(status) {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("iCloudSyncStatus")
    }

    /// The symbol before the status: a cloud with a tick, or with a warning.
    static func iCloudSyncSymbol(_ status: ICloudSyncStatus) -> String {
        switch status {
        case .upToDate:
            "checkmark.icloud"
        case .offline:
            "icloud.slash"
        case .checking, .syncing:
            "icloud"
        case .noAccount, .unavailable, .storageFull, .failed:
            "exclamationmark.icloud"
        }
    }

    /// Whether the status asks the person to do something, so it shows in the warning colour.
    static func iCloudSyncNeedsAttention(_ status: ICloudSyncStatus) -> Bool {
        switch status {
        case .noAccount, .storageFull:
            true
        case .checking, .syncing, .upToDate, .offline, .unavailable, .failed:
            false
        }
    }

    /// Where iCloud Sync has got to, in a few words.
    static func iCloudSyncTitle(_ status: ICloudSyncStatus) -> LocalizedStringResource {
        switch status {
        case .checking:
            LocalizedStringResource(
                "Checking iCloud…",
                comment: "iCloud Sync status in Settings, just after the app opens, before it knows how syncing is going."
            )
        case .syncing:
            LocalizedStringResource("Syncing…", comment: "iCloud Sync status in Settings while the cards are being sent to or fetched from iCloud.")
        case .upToDate:
            LocalizedStringResource(
                "Up to date",
                comment: "iCloud Sync status in Settings when every card on this device is in iCloud and every change in iCloud is here."
            )
        case .noAccount:
            LocalizedStringResource(
                "Not signed in to iCloud",
                comment: "iCloud Sync status in Settings when no one is signed in to iCloud on the device. iCloud is Apple's service; keep the name."
            )
        case .unavailable:
            LocalizedStringResource(
                "iCloud isn't available",
                comment: """
                    iCloud Sync status in Settings when iCloud is restricted, as by Screen Time, or not available for now. \
                    iCloud is Apple's service; keep the name.
                    """
            )
        case .offline:
            LocalizedStringResource(
                "Waiting for a connection",
                comment: "iCloud Sync status in Settings when the device is offline or iCloud could not be reached."
            )
        case .storageFull:
            LocalizedStringResource(
                "iCloud storage is full",
                comment: "iCloud Sync status in Settings when the person's iCloud account has no room left. iCloud is Apple's service; keep the name."
            )
        case .failed:
            LocalizedStringResource("Couldn't sync", comment: "iCloud Sync status in Settings when the last try to sync failed for another reason.")
        }
    }

    /// What to do about the status, or when the cards last synced; nil for nothing more to say.
    static func iCloudSyncDetail(_ status: ICloudSyncStatus) -> LocalizedStringResource? {
        switch status {
        case .checking, .syncing:
            nil
        case let .upToDate(lastSynced):
            lastSyncedDetail(lastSynced)
        case .noAccount:
            LocalizedStringResource(
                "Sign in to iCloud in the Settings app to sync your cards.",
                comment: "Under “Not signed in to iCloud” in Settings. The Settings app is iOS's, not this app's Settings tab."
            )
        case .unavailable:
            LocalizedStringResource(
                "Your cards stay on this device until iCloud is available again.",
                comment: "Under “iCloud isn't available” in Settings: the cards are kept on the device and sync once iCloud is available again."
            )
        case let .offline(lastSynced):
            lastSynced.map(lastSyncedDetail) ?? LocalizedStringResource(
                "Your changes sync once this device is online.",
                comment: "Under “Waiting for a connection” in Settings, when the cards have never synced on this device."
            )
        case .storageFull:
            LocalizedStringResource(
                "Your cards sync again once there is room in your iCloud account.",
                comment: "Under “iCloud storage is full” in Settings. iCloud is Apple's service; keep the name."
            )
        case let .failed(lastSynced):
            lastSynced.map(lastSyncedDetail) ?? LocalizedStringResource(
                "Card Barcodes tries again by itself.",
                comment: "Under “Couldn't sync” in Settings, when the cards have never synced on this device. Card Barcodes is the app's name."
            )
        }
    }

    /// "Last synced 3 minutes ago", counted from now.
    private static func lastSyncedDetail(_ date: Date) -> LocalizedStringResource {
        LocalizedStringResource(
            "Last synced \(date, format: .relative(presentation: .named))",
            comment: """
                Under the iCloud Sync status in Settings: when the cards last synced. \
                The argument is a time from now, such as “3 minutes ago” or “yesterday”.
                """
        )
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
                    Sends crash reports and performance data to Sentry, so the developer can find and fix problems. \
                    Never your cards, your places or anything personal.
                    """,
                    comment: """
                        Under the Share Diagnostics switch in Settings, saying what it sends and what it never does. \
                        Sentry is a company's product name; keep it.
                        """
                ),
                isOn: $sharesDiagnostics,
                identifier: "shareDiagnosticsToggle"
            )
            switchRow(
                Text("Share Usage Data", comment: "Settings switch that lets the app count which of its features are used, with Google Analytics."),
                subtitle: Text(
                    """
                    Counts which features you use, with Google Analytics, so the developer knows what to build next. \
                    Never your cards, your places or anything personal.
                    """,
                    comment: """
                        Under the Share Usage Data switch in Settings, saying what it counts and what it never does. \
                        Google Analytics is Google's product name; keep it.
                        """
                ),
                isOn: $sharesUsageData,
                identifier: "shareUsageDataToggle"
            )
            Text(
                "Turn either off here at any time. Nothing is sent while it is off.",
                comment: """
                    Under the Share Diagnostics and Share Usage Data switches in Settings: \
                    either can be turned off here, and nothing is sent while it is off.
                    """
            )
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .accessibilityIdentifier("privacySwitchesFooter")
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
            Text("Privacy", comment: "Settings section heading for the Share Diagnostics and Share Usage Data switches.")
                .foregroundStyle(Color.secondaryText)
                .accessibilityIdentifier("privacySectionHeader")
        }
    }

    /// One row that opens the open source software the app is built with,
    /// rather than the list itself, which kept the long screen longer.
    var acknowledgementsSection: some View {
        Section {
            NavigationLink {
                AcknowledgementsView(libraries: state.libraries)
            } label: {
                Text(
                    "Acknowledgements",
                    comment: "Settings row, and the title of the screen it opens, listing the open source software the app is built with."
                )
                .foregroundStyle(Color.primaryText)
            }
            .accessibilityIdentifier("acknowledgementsRow")
        }
    }
}
