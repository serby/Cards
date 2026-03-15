# Migrate Unit Tests to Swift Testing + Separate Make Targets

## Scope
Migrate all 6 XCTest unit test files to Swift Testing. UI tests stay as XCTest (XCUIApplication and measure(metrics:) are XCTest-only APIs with no Swift Testing equivalent).

## Key Conversion Rules
| XCTest | Swift Testing |
|--------|--------------|
| `final class FooTests: XCTestCase` | `struct FooTests` |
| `func testFoo()` | `@Test func foo()` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertFalse(x)` | `#expect(!x)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertNotNil(x)` | `#expect(x != nil)` |
| `XCTAssertNoThrow(expr)` | call `expr` directly (throws = fail) |
| `XCTUnwrap(x)` | `try #require(x)` |
| `XCTFail("msg")` | `Issue.record("msg")` |
| `setUpWithError() throws` | `init() throws` |
| `tearDownWithError()` | `deinit` |
| `import XCTest` | `import Testing` |

## Strategy
1. Migrate one simple file first and validate — proves the pattern works end-to-end
2. Migrate the remaining 4 simple files in parallel and validate
3. Migrate NavigationTests (most complex) alone and validate
4. Makefile + cleanup, final E2E validate

## Tasks

| # | File | Status |
|---|------|--------|
| [01](task-01-pilot-settings-view-tests.md) | Pilot: migrate SettingsViewTests.swift | pending |
| [02](task-02-validate-pilot.md) | Validate pilot: make test-unit (interim) | pending |
| [03](task-03-migrate-batch.md) | Migrate BarcodeTypeTests, CardItemTests, PerformanceTrackerTests, BarcodeViewTests (parallel) | pending |
| [04](task-04-validate-batch.md) | Validate batch: make test-unit (interim) | pending |
| [05](task-05-navigation-tests.md) | Migrate NavigationTests.swift (complex) | pending |
| [06](task-06-validate-navigation.md) | Validate navigation: make test-unit | pending |
| [07](task-07-cleanup-makefile.md) | Delete CardsTests.swift, add make test-unit + test-e2e | pending |
| [08](task-08-validate-e2e.md) | Validate: make test-e2e | pending |
