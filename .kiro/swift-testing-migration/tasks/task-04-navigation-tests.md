# Task 04 — Migrate NavigationTests.swift

**Status:** pending  
**File:** `CardsTests/NavigationTests.swift`

## Changes
- `import XCTest` → `import Testing`
- `final class NavigationTests: XCTestCase` → `struct NavigationTests`
- `setUpWithError() throws` → `init() throws`
- `tearDownWithError()` → `deinit` (nil out properties)
- `var navigationManager: NavigationManager?` etc. → `var` stored properties (structs are value types — use `var` on the struct itself, mark struct `@Suite` if needed, or use `mutating` — actually Swift Testing structs recreate per test so init/deinit work correctly)
- `XCTFail("msg")` in `var manager` helper → `Issue.record("msg"); fatalError()`
- `XCTUnwrap(modelContainer)` → `try #require(modelContainer)`
- `XCTAssertEqual` → `#expect(a == b)`
- `XCTAssertNotEqual` → `#expect(a != b)`
- Each `func test_xxx()` → `@Test func xxx()`

## Notes
- Swift Testing creates a new struct instance per test, so `init()`/`deinit` replace setUp/tearDown correctly
- The `manager` computed property uses `XCTFail` + `fatalError` — replace `XCTFail` with `Issue.record`
- All `throws` test functions: keep `throws`, Swift Testing handles them natively
