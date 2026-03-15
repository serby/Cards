# Task 06 — Migrate BarcodeViewTests.swift

**Status:** pending  
**File:** `CardsTests/BarcodeViewTests.swift`

## Changes
- `import XCTest` → `import Testing`
- `final class BarcodeViewTests: XCTestCase` → `struct BarcodeViewTests`
- Each `@MainActor func testXxx()` → `@Test @MainActor func xxx()`
- `XCTAssertNotNil(x, msg)` → `#expect(x != nil, "msg")`
- `XCTAssertTrue(cond, msg)` → `#expect(cond, "msg")`
- `XCTAssertNil(x, msg)` → `#expect(x == nil, "msg")`
- `XCTAssertNotNil(x)` → `#expect(x != nil)`

## Notes
- All tests are `@MainActor` — keep the annotation on each `@Test` func
- `testGenerateBarcodeUnsupportedType` has a tautological if/else — simplify: just call `generateBarcode` and `#expect` the result is not nil (since the test comment admits it can't actually mock the mapper)
- `testBarcodeImageDimensions` references `pointsWidth` — ensure it's accessible from the test module
