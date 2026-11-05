import SwiftData
import SwiftUI
import UIKit

public struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [CardItem]
    @AppStorage("brightnessBoost") private var brightnessBoost = true
    @AppStorage(ArrivalNotifier.enabledKey) private var arrivalNotifications = true
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
            message: $message,
            actions: SettingsActions(
                exportCards: { showExportSheet = true },
                importCards: importJSON,
                deleteAllCards: deleteAllCards,
                readClipboard: { UIPasteboard.general.string },
                openNotificationSettings: openNotificationSettings
            )
        )
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: [exportJSON()])
        }
        // Checked again on coming back, in case notifications were allowed in Settings.
        .task(id: scenePhase) {
            notificationsBlocked = await ArrivalNotifier.isBlockedInSettings()
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
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

    private func importJSON(_ text: String) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = text.data(using: .utf8),
              let dtos = try? decoder.decode([CardItemDTO].self, from: data) else {
            message = "Invalid JSON format"
            return
        }

        for dto in dtos {
            modelContext.insert(dto.toCardItem())
        }

        try? modelContext.save()
        message = "Successfully imported \(dtos.count) cards"
    }

    private func deleteAllCards() {
        for card in cards {
            modelContext.delete(card)
        }
        try? modelContext.save()
    }
}
