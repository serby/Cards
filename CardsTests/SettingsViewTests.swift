//
//  SettingsViewTests.swift
//  CardsTests
//

@testable import Cards
import Foundation
import SwiftData
import Testing

struct SettingsViewTests {

    @Test func deleteAllCardsButtonIsDisabledWhenNoCards() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CardItem.self, configurations: config)
        let context = ModelContext(container)

        let cards = try context.fetch(FetchDescriptor<CardItem>())
        #expect(cards.isEmpty, "Button should be disabled — no cards exist")
    }

    @Test func deleteAllCardsButtonIsEnabledWhenCardsExist() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CardItem.self, configurations: config)
        let context = ModelContext(container)

        context.insert(CardItem(timestamp: Date(), code: "123", name: "Test"))
        try context.save()

        let cards = try context.fetch(FetchDescriptor<CardItem>())
        #expect(!cards.isEmpty, "Button should be enabled — cards exist")
    }
}

/// The counts in Settings use the catalogue's English plural forms, so one
/// card is never "1 cards".
@MainActor
struct SettingsCopyTests {
    private func english(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = Locale(identifier: "en_GB")
        return String(localized: resource)
    }

    @Test func importResultCountsCards() {
        #expect(english(SettingsScreen.importedMessage(count: 1)) == "Imported 1 card")
        #expect(english(SettingsScreen.importedMessage(count: 12)) == "Imported 12 cards")
    }

    /// An export with no cards in it is valid JSON, so the import works, but
    /// "Imported 0 cards" would read as though something went wrong.
    @Test func importOfNoCardsSaysThereWereNone() {
        #expect(english(SettingsScreen.importedMessage(count: 0)) == "No cards to import")
    }

    @Test func deleteAllMessageCountsCards() {
        #expect(
            english(SettingsListView.deleteAllMessage(cardCount: 1))
                == "This will permanently delete 1 card. This action cannot be undone."
        )
        #expect(
            english(SettingsListView.deleteAllMessage(cardCount: 6))
                == "This will permanently delete all 6 cards. This action cannot be undone."
        )
    }
}
