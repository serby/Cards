import Foundation

public protocol PerformanceTracking {
    func recordAppLaunch()
    func recordWarmStart()
    func recordBackgroundTransition()
    func recordForegroundTransition()
}

public final class PerformanceTracker: PerformanceTracking {
    private let appLaunchTime = Date()
    private var foregroundTime: Date?

    public init() {}

    public func recordAppLaunch() {
        let duration = Date().timeIntervalSince(appLaunchTime) * 1_000
        print("Cold Start Time: \(String(format: "%.2f", duration)) ms")
    }

    public func recordWarmStart() {
        guard let foregroundTime = foregroundTime else { return }
        let duration = Date().timeIntervalSince(foregroundTime) * 1_000
        print("Warm Start Time: \(String(format: "%.2f", duration)) ms")
        self.foregroundTime = nil
    }

    public func recordBackgroundTransition() {}

    public func recordForegroundTransition() {
        foregroundTime = Date()
    }
}
