import SwiftUI

/// Read/write access to screen brightness, injected so that views which boost
/// brightness stay runnable outside the app (previews, stories, tests).
public struct ScreenBrightness: Sendable {
    public var read: @MainActor @Sendable () -> CGFloat
    public var write: @MainActor @Sendable (CGFloat) -> Void

    public init(
        read: @escaping @MainActor @Sendable () -> CGFloat,
        write: @escaping @MainActor @Sendable (CGFloat) -> Void
    ) {
        self.read = read
        self.write = write
    }
}

public extension ScreenBrightness {
    /// Drives the real device screen.
    static let system = ScreenBrightness(
        read: { UIScreen.current?.brightness ?? 0.5 },
        write: { UIScreen.current?.brightness = max(0, min(1, $0)) }
    )

    /// Ramps brightness to `target` in fixed steps.
    @MainActor
    func fade(to target: CGFloat, duration: TimeInterval) async {
        let stepTime: TimeInterval = 0.05
        let steps = max(1, Int(duration / stepTime))
        let start = read()
        let delta = (target - start) / CGFloat(steps)

        for _ in 0..<steps {
            write(read() + delta)
            try? await Task.sleep(for: .seconds(stepTime))
        }
        write(target)
    }
}

private struct ScreenBrightnessKey: EnvironmentKey {
    static let defaultValue = ScreenBrightness.system
}

public extension EnvironmentValues {
    var screenBrightness: ScreenBrightness {
        get { self[ScreenBrightnessKey.self] }
        set { self[ScreenBrightnessKey.self] = newValue }
    }
}

/// Posts VoiceOver announcements, injected so stories do not emit them.
public struct AccessibilityAnnouncer: Sendable {
    public var announce: @MainActor @Sendable (String) -> Void

    public init(announce: @escaping @MainActor @Sendable (String) -> Void) {
        self.announce = announce
    }

    public static let system = Self { message in
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

private struct AccessibilityAnnouncerKey: EnvironmentKey {
    static let defaultValue = AccessibilityAnnouncer.system
}

public extension EnvironmentValues {
    var accessibilityAnnouncer: AccessibilityAnnouncer {
        get { self[AccessibilityAnnouncerKey.self] }
        set { self[AccessibilityAnnouncerKey.self] = newValue }
    }
}
