import SwiftUI

/// Posts VoiceOver announcements, injected so stories do not emit them.
public struct AccessibilityAnnouncer: Sendable {
    public var announce: @MainActor @Sendable (String) -> Void

    public init(announce: @escaping @MainActor @Sendable (String) -> Void) {
        self.announce = announce
    }

    /// Speaks through VoiceOver, when it is running.
    public static let live = Self { message in
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

private struct AccessibilityAnnouncerKey: EnvironmentKey {
    static let defaultValue = AccessibilityAnnouncer.live
}

public extension EnvironmentValues {
    var accessibilityAnnouncer: AccessibilityAnnouncer {
        get { self[AccessibilityAnnouncerKey.self] }
        set { self[AccessibilityAnnouncerKey.self] = newValue }
    }
}
