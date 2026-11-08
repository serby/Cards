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
    /// CardsApp opens the store again when this changes (DATA-8).
    @AppStorage(DeviceSettings.syncsWithICloudKey) private var syncsWithICloud = true
    @AppStorage(DeviceSettings.sharesDiagnosticsKey) private var sharesDiagnostics = true
    @Environment(ArrivalScheduler.self) private var arrivalScheduler
    @Environment(\.iCloudCards) private var iCloudCards
    @Environment(\.clipboard) private var clipboard
    @Environment(\.fileReader) private var fileReader
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationsBlocked = false
    @State private var iCloudDeletion = ICloudDeletion.notAsked
    /// Read once: it ships with the app and does not change while it runs.
    private static let changelog = ChangelogStore.bundled()

    @State private var message: String?
    @State private var showExportSheet = false

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
                iCloudDeletion: iCloudDeletion
            ),
            brightnessBoost: $brightnessBoost,
            arrivalNotifications: $arrivalNotifications,
            showsCardWhereYouAre: $showsCardWhereYouAre,
            distanceUnits: $distanceUnits,
            syncsWithICloud: $syncsWithICloud,
            sharesDiagnostics: $sharesDiagnostics,
            message: $message,
            actions: SettingsActions(
                exportCards: { showExportSheet = true },
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
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: [exportJSON()])
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

    private func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let dtos = cards.map { CardItemDTO(from: $0) }
        guard let data = try? encoder.encode(dtos),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func deleteAllCards() {
        for card in cards {
            modelContext.delete(card)
        }
        try? modelContext.save()
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

    /// Imports the file chosen in the Files picker, read with `reader`, and says
    /// what happened. A file that could not be chosen or read is invalid, as
    /// text that is not an export is.
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
    NavigationStack {
        SettingsScreen()
    }
    .environment(ArrivalScheduler(notifications: .silent))
    .modelContainer(for: CardItem.self, inMemory: true)
}
#endif
