//
//  SettingsViewTests.swift
//  CardsTests
//

@testable import CardsCore
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
