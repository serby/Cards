import Foundation

/// What Share Diagnostics may send, as rules the live Sentry client follows
/// (PLAT-14). Kept apart from Sentry so the rules are tested on their own.
public enum DiagnosticsPolicy {
    /// One app start in ten is traced, so a person's day is never a timeline.
    public static let tracesSampleRate = 0.1

    /// The category of the app's own breadcrumbs.
    public static let appCategory = "app.event"

    /// The automatic breadcrumbs that are kept, as none of them carries a
    /// view's text: the app coming and going, the device's events and
    /// orientation, and the app's own. Everything else is dropped: taps, whose
    /// data names the view and can hold a card's name or code, and screens,
    /// whose data carries the screen's title, which could one day be a card's.
    public static let keptBreadcrumbCategories: Set<String> = [
        appCategory, "app.lifecycle", "device.event", "device.orientation"
    ]

    /// Whether a breadcrumb in `category` is kept.
    public static func keepsBreadcrumb(category: String) -> Bool {
        keptBreadcrumbCategories.contains(category)
    }

    /// Where Sentry keeps what it has not sent yet, in the app's caches: its
    /// envelopes, and the crash reports SentryCrash writes. Deleted whenever
    /// Share Diagnostics is off, so a crash from a run with it on is never
    /// sent once it has been turned off.
    public static func pendingReports(in caches: URL) -> [URL] {
        ["io.sentry", "SentryCrash"].map { caches.appending(path: $0, directoryHint: .isDirectory) }
    }

    /// The project Sentry sends to, from the app's Info.plist, or nil when it
    /// has none, in which case nothing is ever started.
    public static func dsn(in info: [String: Any]) -> String? {
        guard let dsn = (info["SentryDSN"] as? String)?.trimmingCharacters(in: .whitespaces), !dsn.isEmpty else { return nil }
        return dsn
    }
}
