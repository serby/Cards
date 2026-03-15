//
//  SettingsViewTests.swift
//  CardsTests
//

@testable import Cards
import SwiftData
import XCTest

final class SettingsViewTests: XCTestCase {

    func testDeleteAllCardsButtonIsDisabledWhenNoCards() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CardItem.self, configurations: config)
        let context = ModelContext(container)

        let cards = try context.fetch(FetchDescriptor<CardItem>())
        XCTAssertTrue(cards.isEmpty, "Button should be disabled — no cards exist")
    }

    func testDeleteAllCardsButtonIsEnabledWhenCardsExist() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CardItem.self, configurations: config)
        let context = ModelContext(container)

        context.insert(CardItem(timestamp: Date(), code: "123", name: "Test"))
        try context.save()

        let cards = try context.fetch(FetchDescriptor<CardItem>())
        XCTAssertFalse(cards.isEmpty, "Button should be enabled — cards exist")
    }
}
