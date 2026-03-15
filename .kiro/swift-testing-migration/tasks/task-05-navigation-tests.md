# Task 05 — Migrate NavigationTests.swift (complex)

**Status:** pending  
**File:** `CardsTests/NavigationTests.swift`

Most complex migration due to setUp/tearDown, optional stored properties, and XCTFail/XCTUnwrap usage.

## Changes

### Imports & type
- `import XCTest` → `import Testing`
- `final class NavigationTests: XCTestCase` → `struct NavigationTests`

### setUp/tearDown → init/deinit
Swift Testing creates a new struct instance per test, so stored properties initialised in `init` are fresh for every test.

```swift
// Before
var navigationManager: NavigationManager?
var modelContainer: ModelContainer?
var modelContext: ModelContext?

override func setUpWithError() throws {
    navigationManager = NavigationManager()
    let schema = Schema([CardItem.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    modelContainer = try ModelContainer(for: schema, configurations: [configuration])
    modelContext = ModelContext(try XCTUnwrap(modelContainer))
}

override func tearDownWithError() throws {
    navigationManager = nil
    modelContext = nil
    modelContainer = nil
}

// After
var navigationManager: NavigationManager
var modelContainer: ModelContainer
var modelContext: ModelContext

init() throws {
    navigationManager = NavigationManager()
    let schema = Schema([CardItem.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    modelContainer = try ModelContainer(for: schema, configurations: [configuration])
    modelContext = ModelContext(modelContainer)
}
```

No `deinit` needed — struct is discarded after each test.

### `manager` helper property
```swift
// Before
var manager: NavigationManager {
    guard let manager = navigationManager else {
        XCTFail("NavigationManager not initialized")
        fatalError("NavigationManager not initialized")
    }
    return manager
}

// After — remove entirely, use navigationManager directly (it's non-optional now)
```

### Assertions
- `XCTAssertEqual(a, b)` → `#expect(a == b)`
- `XCTAssertNotEqual(a, b)` → `#expect(a != b)`
- `XCTUnwrap(x)` → `try #require(x)` (only one usage: `ModelContext(try XCTUnwrap(modelContainer))` — removed since modelContainer is non-optional)
- `func test_xxx() throws` → `@Test func xxx() throws`

### manager references
Replace all `manager.` with `navigationManager.` throughout.
