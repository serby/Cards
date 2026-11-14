import Foundation
import SwiftUI

/// What the app tells its developer, and only with the person's agreement:
/// crash reports and performance data to Sentry while Share Diagnostics is on
/// (PLAT-14), and counts of which features are used to Google Analytics while
/// Share Usage Data is on (PLAT-15). Injected, so only the live value reaches
/// either; every other value sends nothing.
public struct Telemetry: Sendable {
    /// Starts or stops the crash and performance reports, at once.
    public var setSharesDiagnostics: @MainActor @Sendable (Bool) -> Void
    /// Starts or stops the usage counts, at once.
    public var setSharesUsageData: @MainActor @Sendable (Bool) -> Void
    /// Counts `event` with Share Usage Data on, and keeps it as a breadcrumb
    /// with Share Diagnostics on.
    public var record: @Sendable (AppEvent) -> Void
    /// Writes a line to the diagnostics' log, with Share Diagnostics on. The
    /// message is the app's own words, never a card's or a place's text.
    public var log: @Sendable (_ message: String, _ attributes: [String: String]) -> Void
    /// Measures how long something took, in milliseconds, with Share
    /// Diagnostics on.
    public var time: @Sendable (AppTiming, _ milliseconds: Double) -> Void
    /// Counts the cards, as a band, with Share Diagnostics on.
    public var countCards: @Sendable (CountBand) -> Void

    public init(
        setSharesDiagnostics: @escaping @MainActor @Sendable (Bool) -> Void,
        setSharesUsageData: @escaping @MainActor @Sendable (Bool) -> Void,
        record: @escaping @Sendable (AppEvent) -> Void,
        log: @escaping @Sendable (_ message: String, _ attributes: [String: String]) -> Void,
        time: @escaping @Sendable (AppTiming, _ milliseconds: Double) -> Void,
        countCards: @escaping @Sendable (CountBand) -> Void
    ) {
        self.setSharesDiagnostics = setSharesDiagnostics
        self.setSharesUsageData = setSharesUsageData
        self.record = record
        self.log = log
        self.time = time
        self.countCards = countCards
    }
}

public extension Telemetry {
    /// Sends nothing anywhere: for previews, stories and tests, and the
    /// environment's default, so nothing reaches either service by accident.
    static let silent = Self(
        setSharesDiagnostics: { _ in },
        setSharesUsageData: { _ in },
        record: { _ in },
        log: { _, _ in },
        time: { _, _ in },
        countCards: { _ in }
    )

    /// Measures how long `work` takes, as `timing`.
    func measure<Result>(_ timing: AppTiming, _ work: () throws -> Result) rethrows -> Result {
        let start = ContinuousClock.now
        let result = try work()
        let elapsed = ContinuousClock.now - start
        time(timing, Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15)
        return result
    }
}

private struct TelemetryKey: EnvironmentKey {
    static let defaultValue = Telemetry.silent
}

public extension EnvironmentValues {
    var telemetry: Telemetry {
        get { self[TelemetryKey.self] }
        set { self[TelemetryKey.self] = newValue }
    }
}
