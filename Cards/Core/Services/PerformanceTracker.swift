import Foundation
import OSLog

public protocol PerformanceTracking {
    func recordAppLaunch()
    /// The warm start just measured in milliseconds, or nil if this was not one.
    @discardableResult func recordWarmStart() -> Double?
    func recordBackgroundTransition()
    func recordForegroundTransition()
}

public final class PerformanceTracker: PerformanceTracking {
    private static let log = Logger(subsystem: "net.serby.Cards", category: "Performance")
    private let appLaunchTime = Date()
    private var foregroundTime: Date?
    /// The scene's first move to active is the end of launching, not a warm start.
    private var hasLaunched = false

    public init() {}

    public func recordAppLaunch() {
        let duration = Date().timeIntervalSince(appLaunchTime) * 1_000
        Self.log.info("Cold start: \(duration, format: .fixed(precision: 2)) ms")
    }

    @discardableResult
    public func recordWarmStart() -> Double? {
        defer { foregroundTime = nil }
        guard hasLaunched else {
            hasLaunched = true
            return nil
        }
        guard let foregroundTime else { return nil }
        let duration = Date().timeIntervalSince(foregroundTime) * 1_000
        Self.log.info("Warm start: \(duration, format: .fixed(precision: 2)) ms")
        return duration
    }

    public func recordBackgroundTransition() {}

    public func recordForegroundTransition() {
        foregroundTime = Date()
    }
}
