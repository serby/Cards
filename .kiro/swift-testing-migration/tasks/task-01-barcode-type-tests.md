# Task 01 — Migrate BarcodeTypeTests.swift

**Status:** pending  
**File:** `CardsTests/BarcodeTypeTests.swift`

## Changes
- Replace `import XCTest` with `import Testing`
- Remove `@testable import Cards` → keep `@testable import Cards`
- `final class BarcodeTypeTests: XCTestCase` → `struct BarcodeTypeTests`
- Each `func testXxx()` → `@Test func xxx()` (drop `test` prefix)
- All `XCTAssertEqual(a, b)` → `#expect(a == b)`
- All `XCTAssertTrue(x)` → `#expect(x)`
- All `XCTAssertNil(x)` → `#expect(x == nil)`

## Notes
- No setUp/tearDown — straightforward conversion
- `testBarcodeTypeCaseIterable` has `XCTAssertTrue(allCases.contains(...))` × 9 — convert each to `#expect`
- `testBarcodeTypeHashable` has `XCTAssertEqual(barcodeSet.count, 9)` — convert to `#expect`
