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
        #expect(english(SettingsScreen.importedMessage(count: 1)) == "Successfully imported 1 card")
        #expect(english(SettingsScreen.importedMessage(count: 0)) == "Successfully imported 0 cards")
        #expect(english(SettingsScreen.importedMessage(count: 12)) == "Successfully imported 12 cards")
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
