import SwiftData
import SwiftUI
import UIKit

public struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cards: [CardItem]
    @AppStorage("brightnessBoost") private var brightnessBoost = true
    @AppStorage(ArrivalPlan.enabledKey) private var arrivalNotifications = true
    @AppStorage(DeviceSettings.showsCardWhereYouAreKey) private var showsCardWhereYouAre = false
    @AppStorage(DeviceSettings.distanceUnitsKey) private var distanceUnits = DistanceUnits.automatic
    @AppStorage(DeviceSettings.mapsAppKey) private var mapsApp = MapsApp.appleMaps
    /// CardsApp opens the store again when this changes (DATA-8).
    @AppStorage(DeviceSettings.syncsWithICloudKey) private var syncsWithICloud = true
    @AppStorage(DeviceSettings.sharesDiagnosticsKey) private var sharesDiagnostics = true
    @Environment(ArrivalScheduler.self) private var arrivalScheduler
    @Environment(ICloudSyncMonitor.self) private var iCloudSyncMonitor
    @Environment(\.iCloudCards) private var iCloudCards
    @Environment(\.clipboard) private var clipboard
    @Environment(\.fileReader) private var fileReader
    @Environment(\.fileWriter) private var fileWriter
    /// Where today is, for the export's name (DATA-2): the device's own time zone.
    @Environment(\.timeZone) private var timeZone
    /// Hands over a file opened in the app, to import (DATA-11).
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationsBlocked = false
    @State private var iCloudDeletion = ICloudDeletion.notAsked
    /// Read once: it ships with the app and does not change while it runs.
    private static let changelog = ChangelogStore.bundled()

    @State private var message: String?
    /// What the share sheet is sharing; nil when it is not showing.
    @State private var exportItem: ExportItem?

    public init() {}

    public var body: some View {
        SettingsListView(
            state: SettingsState(
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
                authorName: "Paul Serby",
                authorURL: URL(string: "https://github.com/serby"),
                cardCount: cards.count,
                notificationsBlocked: notificationsBlocked,
                changelog: Self.changelog,
                iCloudDeletion: iCloudDeletion,
                iCloudSync: iCloudSyncMonitor.status
            ),
            brightnessBoost: $brightnessBoost,
            arrivalNotifications: $arrivalNotifications,
            showsCardWhereYouAre: $showsCardWhereYouAre,
            distanceUnits: $distanceUnits,
            mapsApp: $mapsApp,
            syncsWithICloud: $syncsWithICloud,
            sharesDiagnostics: $sharesDiagnostics,
            message: $message,
            actions: SettingsActions(
                exportCards: {
                    exportItem = Self.export(cards, on: .now, in: timeZone, writer: fileWriter)
                },
                importCards: { text in
                    message = Self.importText(text, existing: cards, into: modelContext)
                },
                importFile: { choice in
                    message = Self.importFile(choice, reader: fileReader, existing: cards, into: modelContext)
                },
                deleteAllCards: deleteAllCards,
                readClipboard: { clipboard.read() },
                openNotificationSettings: openNotificationSettings,
                deleteICloudCards: deleteICloudCards
            )
        )
        .sheet(item: $exportItem) { item in
            ShareSheet(items: [item.activityItem])
        }
        // An export opened in the app from Files, Mail or AirDrop imports as one
        // chosen with Choose File does (DATA-11). Initial too, as Settings may be
        // appearing for the first time to import it, at launch or from the Cards tab.
        .onChange(of: navigationManager.fileToImport, initial: true) {
            guard let file = navigationManager.fileToImport else { return }
            navigationManager.fileToImport = nil
            // The share sheet would keep the result from showing.
            exportItem = nil
            // Fetched now rather than from the query, which may not have loaded
            // when Settings is built to import, so duplicates are still found.
            let existing = (try? modelContext.fetch(FetchDescriptor<CardItem>())) ?? cards
            message = Self.importFile(.success(file), reader: fileReader, existing: existing, into: modelContext)
            // iOS handed the app a copy to import; it holds every card, so it goes.
            fileWriter.removeHandedOver(file)
        }
        // A deletion said how it went for the time iCloud Sync was off.
        .onChange(of: syncsWithICloud) {
            iCloudDeletion = .notAsked
        }
        // Checked again on coming back, in case notifications were allowed in Settings.
        .task(id: scenePhase) {
            notificationsBlocked = await arrivalScheduler.isBlockedInSettings()
        }
    }

    private func deleteICloudCards() {
        iCloudDeletion = .deleting
        Task {
            iCloudDeletion = await Self.deletion(by: iCloudCards)
        }
    }

    /// Deletes the cards in iCloud with `iCloudCards`, and says how it went.
    static func deletion(by iCloudCards: ICloudCards) async -> ICloudDeletion {
        do {
            try await iCloudCards.deleteAll()
            return .deleted
        } catch {
            return .failed
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        openURL(url)
    }

    private func deleteAllCards() {
        for card in cards {
            modelContext.delete(card)
        }
        try? modelContext.save()
    }
}

/// Exporting the cards (DATA-2).
extension SettingsScreen {
    /// What Export as JSON hands the share sheet.
    enum ExportItem: Hashable, Identifiable {
        /// The export as a file, which the share sheet shows by its name, Save
        /// to Files keeps as a JSON file and Mail sends as an attachment.
        case file(URL)
        /// The export as text, as before 1.5, if the file could not be written.
        case text(String)

        /// Which kind, not the whole export, as one sheet shows at a time.
        var id: String {
            switch self {
            case .file(let url):
                url.path
            case .text:
                "text"
            }
        }

        var activityItem: Any {
            switch self {
            case .file(let url):
                url
            case .text(let json):
                json
            }
        }
    }

    /// What Export as JSON shares: `cards` as a file named for the day `date`
    /// falls on in `timeZone`, written with `writer`, or as text if the file
    /// could not be written. Nil, sharing nothing, if they cannot be encoded.
    static func export(_ cards: [CardItem], on date: Date, in timeZone: TimeZone, writer: FileWriter) -> ExportItem? {
        guard let json = try? CardExport.json(cards) else { return nil }
        if let file = try? writer.write(json, CardExport.fileName(on: date, in: timeZone)) {
            return .file(file)
        }
        return String(bytes: json, encoding: .utf8).map(ExportItem.text)
    }
}

/// Importing an export, pasted or chosen as a file. Both end in `importJSON`,
/// so a file imports exactly as its text would. Each says what happened in
/// `locale`'s language: the app's own unless a test asks for another.
extension SettingsScreen {
    /// What the import alert says when there is nothing it can import.
    static func invalidJSON(locale: Locale = .current) -> String {
        var message = LocalizedStringResource(
            "Invalid JSON format",
            comment: "Import result alert when the pasted text is not a card export. JSON is a file format; keep the name."
        )
        message.locale = locale
        return String(localized: message)
    }

    /// Imports pasted text, and says what happened.
    static func importText(_ text: String, existing: [CardItem], into context: ModelContext, locale: Locale = .current) -> String {
        importJSON(Data(text.utf8), existing: existing, into: context, locale: locale)
    }

    /// Imports the file chosen in the Files picker, or opened in the app from
    /// Files, Mail or AirDrop, read with `reader`, and says what happened. A file
    /// that could not be chosen or read is invalid, as text that is not an export is.
    static func importFile(
        _ choice: Result<URL, any Error>,
        reader: FileReader,
        existing: [CardItem],
        into context: ModelContext,
        locale: Locale = .current
    ) -> String {
        guard let data = try? reader.read(choice.get()) else { return invalidJSON(locale: locale) }
        return importJSON(data, existing: existing, into: context, locale: locale)
    }

    /// Adds the cards in an export to `context`, after `existing`, and says what
    /// happened (`CardImport`). Nothing is added unless it is a JSON array of cards.
    static func importJSON(_ data: Data, existing: [CardItem], into context: ModelContext, locale: Locale = .current) -> String {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let dtos = try? decoder.decode([CardItemDTO].self, from: data) else {
            return invalidJSON(locale: locale)
        }
        let result = CardImport.cards(from: dtos, existing: existing)
        result.added.forEach(context.insert)
        try? context.save()
        return CardImport.summary(result, locale: locale)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var iCloudSync = ICloudSyncMonitor(sync: .upToDate(ago: 3 * 60))
    NavigationStack {
        SettingsScreen()
    }
    .environment(ArrivalScheduler(notifications: .silent))
    .environment(iCloudSync)
    .environment(NavigationManager())
    .task { await iCloudSync.run() }
    .modelContainer(for: CardItem.self, inMemory: true)
}
#endif
