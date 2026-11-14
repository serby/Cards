// Internal, so nothing outside the app, such as its UI tests, needs Firebase's
// or Sentry's modules to see the app's.
internal import FirebaseAnalytics
internal import FirebaseCore
import Foundation
import os
// Sentry predates strict concurrency: its `SentrySDK.metrics` is a static var it
// guards itself.
@preconcurrency internal import Sentry

public extension Telemetry {
    /// Sentry and Google Analytics, each only while its switch is on. Sentry is
    /// started only once Share Diagnostics is on, rather than started and
    /// disabled, so with it off there is nothing to collect or keep. Firebase,
    /// likewise, is set up only once Share Usage Data is on, with collection off
    /// until then as the app's Info.plist ships it.
    /// `environment` tells Debug builds' reports from the App Store's.
    static func live(environment: String) -> Self {
        let state = OSAllocatedUnfairLock(initialState: LiveState())
        return Self(
            setSharesDiagnostics: { on in
                // Once per change, however many windows see it.
                guard state.withLock({ $0.diagnosticsChosen != SwitchChoice(on) }) else { return }
                state.withLock { $0.diagnosticsChosen = SwitchChoice(on) }
                if on {
                    startSentry(environment: environment)
                } else {
                    stopSentry()
                }
                state.withLock { $0.sharesDiagnostics = on && SentrySDK.isEnabled }
            },
            setSharesUsageData: { on in
                guard state.withLock({ $0.usageChosen != SwitchChoice(on) }) else { return }
                state.withLock {
                    $0.usageChosen = SwitchChoice(on)
                    $0.sharesUsageData = on
                }
                // Off, Firebase is never set up, so it contacts nothing at all; once
                // it has been, turning it off stops it and forgets its identifier.
                guard on || FirebaseApp.app() != nil else { return }
                if FirebaseApp.app() == nil {
                    FirebaseApp.configure()
                }
                // Ad storage, ad user data and ad personalisation are always denied.
                Analytics.setConsent([
                    .analyticsStorage: on ? .granted : .denied,
                    .adStorage: .denied,
                    .adUserData: .denied,
                    .adPersonalization: .denied
                ])
                Analytics.setAnalyticsCollectionEnabled(on)
                if !on {
                    // So turning it on again later starts afresh.
                    Analytics.resetAnalyticsData()
                }
            },
            record: { event in
                let (diagnostics, usage) = state.withLock { ($0.sharesDiagnostics, $0.sharesUsageData) }
                if usage {
                    Analytics.logEvent(event.name, parameters: event.parameters)
                }
                if diagnostics {
                    let crumb = Breadcrumb(level: .info, category: DiagnosticsPolicy.appCategory)
                    crumb.message = event.name
                    for (key, value) in event.parameters {
                        crumb.setData(value: value, key: key)
                    }
                    SentrySDK.addBreadcrumb(crumb)
                }
            },
            log: { message, attributes in
                guard state.withLock({ $0.sharesDiagnostics }) else { return }
                SentrySDK.logger.info(message, attributes: attributes)
            },
            time: { timing, milliseconds in
                guard state.withLock({ $0.sharesDiagnostics }) else { return }
                SentrySDK.metrics.distribution(timing.rawValue, value: milliseconds, options: SentryMetricOptions(unit: .millisecond))
            },
            countCards: { band in
                guard state.withLock({ $0.sharesDiagnostics }) else { return }
                SentrySDK.metrics.count("cards", value: 1, options: SentryMetricOptions(attributes: ["band": band.rawValue]))
            }
        )
    }
}

/// Which switches are on, read from any thread.
private struct LiveState {
    var sharesDiagnostics = false
    var sharesUsageData = false
    /// What each switch was last set to, so a change is followed once.
    var diagnosticsChosen = SwitchChoice.unset
    var usageChosen = SwitchChoice.unset
}

/// A switch as last set, or not yet.
private enum SwitchChoice {
    case unset, on, off

    init(_ on: Bool) {
        self = on ? .on : .off
    }
}

private let logger = Logger(subsystem: "net.serby.Cards", category: "Telemetry")

@MainActor
private func startSentry(environment: String) {
    guard !SentrySDK.isEnabled else { return }
    guard let dsn = DiagnosticsPolicy.dsn(in: Bundle.main.infoDictionary ?? [:]) else {
        logger.notice("Share Diagnostics is on, but the app has no Sentry DSN, so nothing is sent")
        return
    }
    SentrySDK.start { options in
        options.dsn = dsn
        options.environment = environment
        // No user and no IP address are attached.
        options.sendDefaultPii = false
        options.tracesSampleRate = NSNumber(value: DiagnosticsPolicy.tracesSampleRate)
        // Each of these would be a picture of a card, or name the views tapped.
        options.attachScreenshot = false
        options.attachViewHierarchy = false
        options.sessionReplay.sessionSampleRate = 0
        options.sessionReplay.onErrorSampleRate = 0
        options.enableUserInteractionTracing = false
        // Requests' addresses can hold what was searched for a place.
        options.enableNetworkTracking = false
        options.enableNetworkBreadcrumbs = false
        options.enableCaptureFailedRequests = false
        // File and database spans are named after the files and records read,
        // which can be a file the person imported.
        options.enableFileIOTracing = false
        options.enableDataSwizzling = false
        options.enableFileManagerSwizzling = false
        options.enableCoreDataTracing = false
        // Turning Share Diagnostics off sends nothing more: closing waits for no flush.
        options.shutdownTimeInterval = 0
        options.beforeBreadcrumb = { crumb in
            DiagnosticsPolicy.keepsBreadcrumb(category: crumb.category) ? crumb : nil
        }
        options.beforeSend = { event in
            event.user = nil
            event.request = nil
            event.breadcrumbs = event.breadcrumbs?.filter { DiagnosticsPolicy.keepsBreadcrumb(category: $0.category) }
            return event
        }
    }
}

@MainActor
private func stopSentry() {
    // Whatever was kept to send, such as the last run's crash, goes first, unsent.
    let pending = DiagnosticsPolicy.pendingReports(in: URL.cachesDirectory)
    pending.forEach { try? FileManager.default.removeItem(at: $0) }
    if SentrySDK.isEnabled {
        SentrySDK.close()
        pending.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
