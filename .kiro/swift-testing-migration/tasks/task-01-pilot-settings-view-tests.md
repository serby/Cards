# Task 01 — Pilot: Migrate SettingsViewTests.swift

**Status:** done  
**File:** `CardsTests/SettingsViewTests.swift`

Simplest file — two tests, no setUp/tearDown, no async. Proves the pattern works before touching anything else.

## Changes
- `import XCTest` → `import Testing`
- `final class SettingsViewTests: XCTestCase` → `struct SettingsViewTests`
- `func testXxx() throws` → `@Test func xxx() throws`
- `XCTAssertTrue(x, msg)` → `#expect(x, "msg")`
- `XCTAssertFalse(x, msg)` → `#expect(!x, "msg")`
