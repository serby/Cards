import SwiftUI

/// Posts VoiceOver announcements, injected so stories do not emit them. An
/// attributed message carries speech attributes, such as a code spelled out
/// character by character.
public struct AccessibilityAnnouncer: Sendable {
    public var post: @MainActor @Sendable (AttributedString) -> Void

    public init(post: @escaping @MainActor @Sendable (AttributedString) -> Void) {
        self.post = post
    }

    /// Speaks through VoiceOver, when it is running.
    public static let live = Self { message in
        AccessibilityNotification.Announcement(message).post()
    }

    @MainActor
    public func announce(_ message: String) {
        post(AttributedString(message))
    }

    @MainActor
    public func announce(_ message: AttributedString) {
        post(message)
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
