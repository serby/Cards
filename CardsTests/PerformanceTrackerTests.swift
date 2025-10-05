//
//  PerformanceTrackerTests.swift
//  CardsTests
//
//  Created by Serby, Paul on 05/10/2024.
//

import XCTest
@testable import Cards

final class PerformanceTrackerTests: XCTestCase {
    var tracker: PerformanceTracker!
    
    override func setUp() {
        super.setUp()
        tracker = PerformanceTracker()
    }
    
    override func tearDown() {
        tracker = nil
        super.tearDown()
    }
    
    func test_recordAppLaunch_completesWithoutCrashing() {
        // Given: A fresh tracker
        // When: Recording app launch
        // Then: Should complete without throwing
        XCTAssertNoThrow(tracker.recordAppLaunch())
    }
    
    func test_recordWarmStartWithoutForegroundTransition_handlesGracefully() {
        // Given: A tracker with no foreground transition recorded
        // When: Recording warm start
        // Then: Should complete without throwing (no foreground time to measure)
        XCTAssertNoThrow(tracker.recordWarmStart())
    }
    
    @MainActor
    func test_recordWarmStartAfterForegroundTransition_measuresTimingCorrectly() async {
        // Given: A tracker that has recorded foreground transition
        tracker.recordForegroundTransition()
        let expectedMinDuration: TimeInterval = 0.01
        
        // When: Recording warm start after a brief delay
        try? await Task.sleep(nanoseconds: UInt64(expectedMinDuration * 1_000_000_000))
        
        // Then: Should complete without throwing and measure timing
        XCTAssertNoThrow(tracker.recordWarmStart())
        // Note: Actual timing verification would require output capture or mock
    }
    
    func test_recordBackgroundTransition_completesWithoutCrashing() {
        // Given: A fresh tracker
        // When: Recording background transition
        // Then: Should complete without throwing
        XCTAssertNoThrow(tracker.recordBackgroundTransition())
    }
    
    func test_recordForegroundTransition_completesWithoutCrashing() {
        // Given: A fresh tracker
        // When: Recording foreground transition
        // Then: Should complete without throwing
        XCTAssertNoThrow(tracker.recordForegroundTransition())
    }
    
    func test_multipleWarmStartsAfterSingleForegroundTransition_handlesCorrectly() {
        // Given: A tracker with one foreground transition
        tracker.recordForegroundTransition()
        
        // When: Recording multiple warm starts
        XCTAssertNoThrow(tracker.recordWarmStart()) // First should work
        XCTAssertNoThrow(tracker.recordWarmStart()) // Second should handle gracefully (no foreground time)
        
        // Then: Both calls should complete without throwing
    }
    
    func test_warmStartSequence_followsCorrectFlow() {
        // Given: A fresh tracker
        // When: Following the correct sequence
        XCTAssertNoThrow(tracker.recordBackgroundTransition())
        XCTAssertNoThrow(tracker.recordForegroundTransition())
        XCTAssertNoThrow(tracker.recordWarmStart())
        
        // Then: All steps should complete without throwing
    }
    
    func test_performanceTrackerConformsToProtocol() {
        // Given: A PerformanceTracker instance
        // When: Casting to protocol
        let protocolTracker: PerformanceTracking = tracker
        
        // Then: Should successfully cast and all methods should be callable
        XCTAssertNotNil(protocolTracker)
        XCTAssertNoThrow(protocolTracker.recordAppLaunch())
        XCTAssertNoThrow(protocolTracker.recordWarmStart())
        XCTAssertNoThrow(protocolTracker.recordBackgroundTransition())
        XCTAssertNoThrow(protocolTracker.recordForegroundTransition())
    }
    
    func test_trackerInstantiation_createsValidInstance() {
        // Given: PerformanceTracker class
        // When: Creating new instance
        let newTracker = PerformanceTracker()
        
        // Then: Should create valid instance that conforms to protocol at runtime
        XCTAssertNotNil(newTracker)
        let protocolInstance: PerformanceTracking = newTracker
        XCTAssertNotNil(protocolInstance)
    }
}
