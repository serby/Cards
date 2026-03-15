# Task 01 — Fix SettingsViewTests.swift

**Status:** done
**Completed:** 2026-03-15  
**File:** `CardsTests/SettingsViewTests.swift`

## Problem
The existing tests assert `cards.isEmpty` twice with different messages — the second assertion is identical to the first and adds no value. Neither test actually verifies the view's disabled state; they only verify the data condition.

## Fix
Rewrite both tests to:
- Assert the correct boolean condition once, clearly
- Use `XCTAssertTrue`/`XCTAssertFalse` with a single meaningful message
- Keep the in-memory `ModelContainer` setup (correct approach)

## Expected result
```swift
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
```
