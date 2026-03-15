# Task 05 — Migrate SettingsViewTests.swift

**Status:** pending  
**File:** `CardsTests/SettingsViewTests.swift`

## Changes
- `import XCTest` → `import Testing`
- `final class SettingsViewTests: XCTestCase` → `struct SettingsViewTests`
- `func testXxx() throws` → `@Test func xxx() throws`
- `XCTAssertTrue(x, msg)` → `#expect(x, "msg")`
- `XCTAssertFalse(x, msg)` → `#expect(!x, "msg")`

## Notes
- Simplest migration — no setUp/tearDown, no async, two tests
