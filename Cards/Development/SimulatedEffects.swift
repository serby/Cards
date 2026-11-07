import SwiftUI
import UserNotifications

public extension ScreenBrightness {
    /// Keeps a value in memory without touching the device, so stories can show
    /// the brightness a view asked for without blinding the operator.
    static func simulated(_ box: BrightnessBox) -> ScreenBrightness {
        ScreenBrightness(
            read: { box.level },
            write: { box.level = max(0, min(1, $0)) }
        )
    }
}

/// Observable holder for `ScreenBrightness.simulated`.
@MainActor
@Observable
public final class BrightnessBox {
    public var level: CGFloat

    public init(level: CGFloat = 0.5) {
        self.level = level
    }
}

public extension AccessibilityAnnouncer {
    /// Swallows announcements, so stories and previews never speak.
    static let silent = Self { _ in }
}

public extension NotificationClient {
    /// Schedules nothing and reports that permission was never asked, so
    /// previews of the connectors never prompt or notify.
    static let silent = Self(
        add: { _ in },
        addAfter: { _, _ in },
        removeAllPending: {},
        requestAuthorization: { false },
        authorizationStatus: { .notDetermined }
    )
}

public extension BarcodeImportActions {
    /// Reads every photo and file as `reading`, after a moment so the story
    /// shows "Reading the barcode…" first. Nothing is opened or sent to Vision.
    static func always(_ reading: BarcodeReading) -> Self {
        let simulated: () async -> BarcodeReading = {
            try? await Task.sleep(for: .seconds(0.8))
            return reading
        }
        return Self(readPhoto: { _ in await simulated() }, readFile: { _ in await simulated() })
    }
}

extension AppLanguageClient {
    /// Keeps the override in `box` and never quits, so stories and previews
    /// of the Language tool can choose a language without closing the app.
    static func simulated(_ box: LanguageOverrideBox) -> Self {
        Self(
            override: { box.override },
            setOverride: { box.override = $0 },
            quit: {}
        )
    }
}

/// Observable holder for `AppLanguageClient.simulated`.
@MainActor
@Observable
final class LanguageOverrideBox {
    var override: [String]

    init(override: [String] = []) {
        self.override = override
    }
}
