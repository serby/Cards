# Task 02 — Migrate CardItemTests.swift

**Status:** pending  
**File:** `CardsTests/CardItemTests.swift`

## Changes
- `import XCTest` → `import Testing`
- `final class CardItemTests: XCTestCase` → `struct CardItemTests`
- Each `func testXxx()` → `@Test func xxx()`
- `XCTAssertEqual` → `#expect(a == b)`
- `XCTAssertTrue(true)` in `testIdentifiableConformance` → remove entirely (compile-time check only)

## Notes
- No setUp/tearDown — straightforward conversion
- The `testIdentifiableConformance` test just does `_ = cardItem.id` then `XCTAssertTrue(true)` — keep the `_ = cardItem.id` line, drop the assertion
