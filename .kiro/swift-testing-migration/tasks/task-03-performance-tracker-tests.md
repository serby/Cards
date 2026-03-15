# Task 03 — Migrate PerformanceTrackerTests.swift

**Status:** pending  
**File:** `CardsTests/PerformanceTrackerTests.swift`

## Changes
- `import XCTest` → `import Testing`
- `final class PerformanceTrackerTests: XCTestCase` → `struct PerformanceTrackerTests`
- Each `func test_xxx()` → `@Test func xxx()` (drop `test_` prefix)
- `XCTAssertNoThrow(expr)` → call `expr` directly (if it throws, the test fails automatically)
- `XCTAssertNotNil(x)` → `#expect(x != nil)`
- `async` test: keep `async` on the `@Test` function

## Notes
- `test_recordWarmStartAfterForegroundTransition_measuresTimingCorrectly` is `async` — keep `async` on the `@Test` func
- `XCTAssertNoThrow` wraps are the main pattern here — just unwrap them, calling the expression directly
