# Testing Guidelines for Swift/iOS

## Core Testing Principles

### 1. Meaningful Assertions
**Never use generic assertions that always pass**

```swift
// ❌ BAD - Always passes
XCTAssertTrue(true, "Should complete")

// ✅ GOOD - Tests actual behavior
XCTAssertEqual(result.count, 3)
XCTAssertNil(error)
XCTAssertGreaterThan(duration, 0.0)
```

### 2. Input Boundary Testing
**Test edge cases and boundary conditions**

```swift
func testWithBoundaryValues() {
    // Empty/nil inputs
    XCTAssertNil(parser.parse(""))
    XCTAssertNil(parser.parse(nil))
    
    // Zero values
    XCTAssertEqual(calculator.divide(10, by: 0), nil)
    
    // Negative values
    XCTAssertThrows(try validator.validate(-1))
    
    // Maximum values
    XCTAssertNoThrow(try processor.handle(Int.max))
    
    // Minimum values
    XCTAssertNoThrow(try processor.handle(Int.min))
}
```

### 3. State Verification
**Verify object state changes, not just completion**

```swift
// ❌ BAD
func testAddItem() {
    manager.addItem("test")
    XCTAssertTrue(true) // Meaningless
}

// ✅ GOOD
func testAddItem() {
    let initialCount = manager.items.count
    manager.addItem("test")
    
    XCTAssertEqual(manager.items.count, initialCount + 1)
    XCTAssertEqual(manager.items.last, "test")
}
```

### 4. Error Condition Testing
**Test failure paths explicitly**

```swift
func testErrorHandling() {
    // Test specific error types
    XCTAssertThrowsError(try service.process(invalidData)) { error in
        XCTAssertTrue(error is ValidationError)
        XCTAssertEqual((error as? ValidationError)?.code, .invalidFormat)
    }
    
    // Test error recovery
    service.reset()
    XCTAssertNoThrow(try service.process(validData))
}
```

## Testing Patterns

### 1. Given-When-Then Structure
```swift
func testFeature() {
    // Given: Setup test conditions
    let input = TestData.validInput
    let expectedOutput = TestData.expectedResult
    
    // When: Execute the behavior
    let result = service.process(input)
    
    // Then: Verify outcomes
    XCTAssertEqual(result, expectedOutput)
    XCTAssertEqual(service.state, .completed)
}
```

### 2. Timing and Performance Tests
```swift
@MainActor
func testPerformanceTiming() async {
    let startTime = Date()
    
    await service.performOperation()
    
    let duration = Date().timeIntervalSince(startTime)
    XCTAssertLessThan(duration, 1.0, "Operation should complete within 1 second")
    XCTAssertGreaterThan(duration, 0.001, "Operation should take measurable time")
}
```

### 3. Mock Verification
```swift
func testServiceInteraction() {
    let mockDelegate = MockDelegate()
    service.delegate = mockDelegate
    
    service.performAction()
    
    XCTAssertEqual(mockDelegate.callCount, 1)
    XCTAssertEqual(mockDelegate.lastCalledWith, expectedParameter)
}
```

## Coverage Requirements

### 1. Method Coverage
- **100% of public methods** must have tests
- **Critical private methods** should be tested via public interface
- **Error paths** must be tested, not just happy paths

### 2. Branch Coverage
```swift
func testAllBranches() {
    // Test true branch
    XCTAssertEqual(service.process(validInput), expectedResult)
    
    // Test false branch
    XCTAssertNil(service.process(invalidInput))
    
    // Test edge cases
    XCTAssertEqual(service.process(edgeCaseInput), edgeResult)
}
```

### 3. Data Type Coverage
```swift
func testDataTypes() {
    // String variations
    testWith("")           // Empty
    testWith("a")          // Single char
    testWith("normal")     // Normal case
    testWith("very long string with special chars !@#$%") // Edge case
    
    // Numeric variations
    testWith(0)            // Zero
    testWith(-1)           // Negative
    testWith(Int.max)      // Maximum
    testWith(Int.min)      // Minimum
    
    // Collection variations
    testWith([])           // Empty array
    testWith([single])     // Single item
    testWith(largeArray)   // Many items
}
```

## Anti-Patterns to Avoid

### ❌ Generic Success Assertions
```swift
XCTAssertTrue(true)
XCTAssertNotNil(object) // Without checking object properties
```

### ❌ Testing Implementation Details
```swift
// Don't test private method names or internal structure
XCTAssertEqual(service.internalCounter, 5) // Bad if internalCounter is private
```

### ❌ Brittle Tests
```swift
// Don't rely on exact string matches for error messages
XCTAssertEqual(error.localizedDescription, "Exact error message") // Fragile
```

## Best Practices

### 1. Test Naming
```swift
// Pattern: test_[condition]_[expectedBehavior]
func test_emptyInput_returnsNil()
func test_validData_updatesStateCorrectly()
func test_networkError_retriesThreeTimes()
```

### 2. Test Data Management
```swift
enum TestData {
    static let validUser = User(id: 1, name: "Test")
    static let invalidUser = User(id: -1, name: "")
    static let largeDataSet = (1...1000).map { User(id: $0, name: "User\($0)") }
}
```

### 3. Async Testing
```swift
@MainActor
func testAsyncOperation() async {
    let expectation = XCTestExpectation(description: "Async operation completes")
    
    let result = await service.asyncOperation()
    
    XCTAssertNotNil(result)
    XCTAssertEqual(result.status, .success)
    expectation.fulfill()
    
    await fulfillment(of: [expectation], timeout: 5.0)
}
```

### 4. Memory and Resource Testing
```swift
func testMemoryManagement() {
    weak var weakReference: MyObject?
    
    autoreleasepool {
        let object = MyObject()
        weakReference = object
        service.process(object)
    }
    
    XCTAssertNil(weakReference, "Object should be deallocated")
}
```

## Quality Gates

### Before Merging Code
- [ ] All public methods have tests
- [ ] Error conditions are tested
- [ ] Boundary values are tested
- [ ] No generic `XCTAssertTrue(true)` assertions
- [ ] Test names clearly describe scenarios
- [ ] Async operations properly tested
- [ ] Memory leaks checked for retain cycles
- [ ] Performance critical paths have timing tests

### Test Review Checklist
- [ ] Tests verify actual behavior, not just completion
- [ ] Edge cases and error conditions covered
- [ ] Assertions are specific and meaningful
- [ ] Test data covers boundary conditions
- [ ] No flaky or timing-dependent tests
- [ ] Tests are independent and can run in any order
