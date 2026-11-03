import Foundation
import OSLog

public protocol PerformanceTracking {
    func recordAppLaunch()
    func recordWarmStart()
    func recordBackgroundTransition()
    func recordForegroundTransition()
}

public final class PerformanceTracker: PerformanceTracking {
    private static let log = Logger(subsystem: "net.serby.Cards", category: "Performance")
    private let appLaunchTime = Date()
    private var foregroundTime: Date?

    public init() {}

    public func recordAppLaunch() {
        let duration = Date().timeIntervalSince(appLaunchTime) * 1_000
        Self.log.info("Cold start: \(duration, format: .fixed(precision: 2)) ms")
    }

    public func recordWarmStart() {
        guard let foregroundTime = foregroundTime else { return }
        let duration = Date().timeIntervalSince(foregroundTime) * 1_000
        Self.log.info("Warm start: \(duration, format: .fixed(precision: 2)) ms")
        self.foregroundTime = nil
    }

    public func recordBackgroundTransition() {}

    public func recordForegroundTransition() {
        foregroundTime = Date()
    }
}
