import SwiftData
import SwiftUI
import UIKit

public struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CardItem.order) private var cards: [CardItem]
    @AppStorage("brightnessBoost") private var brightnessBoost = true
    @AppStorage(ArrivalPlan.enabledKey) private var arrivalNotifications = true
    @AppStorage(DeviceSettings.showsCardWhereYouAreKey) private var showsCardWhereYouAre = false
    @Environment(ArrivalScheduler.self) private var arrivalScheduler
    @Environment(\.clipboard) private var clipboard
    @Environment(\.fileReader) private var fileReader
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationsBlocked = false
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
                changelog: Self.changelog
            ),
            brightnessBoost: $brightnessBoost,
            arrivalNotifications: $arrivalNotifications,
            showsCardWhereYouAre: $showsCardWhereYouAre,
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
                openNotificationSettings: openNotificationSettings
            )
        )
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: [exportJSON()])
        }
        // Checked again on coming back, in case notifications were allowed in Settings.
        .task(id: scenePhase) {
            notificationsBlocked = await arrivalScheduler.isBlockedInSettings()
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
/// so a file imports exactly as its text would.
extension SettingsScreen {
    /// What the import alert says when there is nothing it can import.
    static let invalidJSON = "Invalid JSON format"

    /// Imports pasted text, and says what happened.
    static func importText(_ text: String, existing: [CardItem], into context: ModelContext) -> String {
        importJSON(Data(text.utf8), existing: existing, into: context)
    }

    /// Imports the file chosen in the Files picker, read with `reader`, and says
    /// what happened. A file that could not be chosen or read is invalid, as
    /// text that is not an export is.
    static func importFile(
        _ choice: Result<URL, any Error>,
        reader: FileReader,
        existing: [CardItem],
        into context: ModelContext
    ) -> String {
        guard let data = try? reader.read(choice.get()) else { return invalidJSON }
        return importJSON(data, existing: existing, into: context)
    }

    /// Adds the cards in an export to `context`, after `existing`, and says what
    /// happened (`CardImport`). Nothing is added unless it is a JSON array of cards.
    static func importJSON(_ data: Data, existing: [CardItem], into context: ModelContext) -> String {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let dtos = try? decoder.decode([CardItemDTO].self, from: data) else {
            return invalidJSON
        }
        let result = CardImport.cards(from: dtos, existing: existing)
        result.added.forEach(context.insert)
        try? context.save()
        return CardImport.summary(result)
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
