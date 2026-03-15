# Task 03 — Migrate Batch (parallel)

**Status:** pending  
**Files:** BarcodeTypeTests.swift, CardItemTests.swift, PerformanceTrackerTests.swift, BarcodeViewTests.swift

Run as 4 parallel subagents.

## BarcodeTypeTests.swift ✅
- `import XCTest` → `import Testing`
- `final class BarcodeTypeTests: XCTestCase` → `struct BarcodeTypeTests`
- `func testXxx()` → `@Test func xxx()`
- `XCTAssertEqual(a, b)` → `#expect(a == b)`
- `XCTAssertTrue(x)` → `#expect(x)`
- `XCTAssertNil(x)` → `#expect(x == nil)`

**Note:** BarcodeTypeTests migration complete. All 6 tests migrated to Swift Testing.

## CardItemTests.swift ✅ Done
- Same class/import/assertion conversions
- `testIdentifiableConformance`: drop `XCTAssertTrue(true)` — keep `_ = cardItem.id`, no assertion needed
- Migrated: struct, `@Test`, `#expect`, `import Foundation` added, comments removed

## PerformanceTrackerTests.swift ✅
- Same class/import conversions
- `XCTAssertNoThrow(expr)` → call `expr` directly (no wrapper)
- `XCTAssertNotNil(x)` → `#expect(x != nil)`
- Keep `async` on the one async test
- **Done** — migrated to Swift Testing struct with `@Test` functions

## BarcodeViewTests.swift ✅
- Migrated to Swift Testing: `struct BarcodeViewTests`, `import Testing`, `@Test @MainActor` on all tests
- Dropped `test` prefix from all function names
- Converted all XCTest assertions to `#expect`
- Simplified tautological `testGenerateBarcodeUnsupportedType` to single `#expect(result != nil)`
- Converted `XCTAssertEqual` with accuracy to `#expect(abs(a - b) <= tolerance)`
- Removed all comments
