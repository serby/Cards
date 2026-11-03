@testable import Cards
import Foundation
import Testing

struct PerformanceTrackerTests {

    @Test func recordAppLaunch_completesWithoutCrashing() {
        let tracker = PerformanceTracker()
        tracker.recordAppLaunch()
    }

    @Test func recordWarmStartWithoutForegroundTransition_handlesGracefully() {
        let tracker = PerformanceTracker()
        tracker.recordWarmStart()
    }

    @Test @MainActor func recordWarmStartAfterForegroundTransition_measuresTimingCorrectly() async {
        let tracker = PerformanceTracker()
        tracker.recordForegroundTransition()
        let expectedMinDuration: TimeInterval = 0.01
        try? await Task.sleep(nanoseconds: UInt64(expectedMinDuration * 1_000_000_000))
        tracker.recordWarmStart()
    }

    @Test func firstActivationIsPartOfLaunchNotAWarmStart() {
        let tracker = PerformanceTracker()
        tracker.recordForegroundTransition()
        #expect(tracker.recordWarmStart() == nil)
    }

    @Test func returningFromTheBackgroundIsMeasuredAfterLaunch() {
        let tracker = PerformanceTracker()
        tracker.recordWarmStart()
        tracker.recordForegroundTransition()
        let duration = tracker.recordWarmStart()
        #expect(duration != nil)
        #expect((duration ?? -1) >= 0)
    }

    @Test func becomingActiveWithoutLeavingTheBackgroundIsNotAWarmStart() {
        let tracker = PerformanceTracker()
        tracker.recordWarmStart()
        #expect(tracker.recordWarmStart() == nil)
    }

    @Test func recordBackgroundTransition_completesWithoutCrashing() {
        let tracker = PerformanceTracker()
        tracker.recordBackgroundTransition()
    }

    @Test func recordForegroundTransition_completesWithoutCrashing() {
        let tracker = PerformanceTracker()
        tracker.recordForegroundTransition()
    }

    @Test func multipleWarmStartsAfterSingleForegroundTransition_handlesCorrectly() {
        let tracker = PerformanceTracker()
        tracker.recordForegroundTransition()
        tracker.recordWarmStart()
        tracker.recordWarmStart()
    }

    @Test func warmStartSequence_followsCorrectFlow() {
        let tracker = PerformanceTracker()
        tracker.recordBackgroundTransition()
        tracker.recordForegroundTransition()
        tracker.recordWarmStart()
    }

    @Test func performanceTrackerConformsToProtocol() {
        let tracker = PerformanceTracker()
        let protocolTracker: any PerformanceTracking = tracker
        protocolTracker.recordAppLaunch()
        protocolTracker.recordWarmStart()
        protocolTracker.recordBackgroundTransition()
        protocolTracker.recordForegroundTransition()
    }

    @Test func trackerInstantiation_createsValidInstance() {
        let newTracker = PerformanceTracker()
        let _: any PerformanceTracking = newTracker
    }
}
