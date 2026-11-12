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
    static let live = ScreenBrightness(
        read: { UIScreen.current?.brightness ?? 0.5 },
        write: { UIScreen.current?.brightness = max(0, min(1, $0)) }
    )

}

/// The boost a card's screen gives the screen while Brightness Boost is on
/// (BAR-4): full brightness at once, and the brightness it found put back at
/// once when it ends, as when the card closes or the app leaves the foreground.
public struct BrightnessBoost: Sendable {
    /// The brightness before the boost, while it is on.
    public private(set) var original: CGFloat?

    public init() {}

    public var isOn: Bool {
        original != nil
    }

    /// Turns `screen` up to full, remembering where it was unless the boost is
    /// already on, so starting twice still puts back the brightness found first.
    @MainActor
    public mutating func start(on screen: ScreenBrightness) {
        if original == nil {
            original = screen.read()
        }
        screen.write(1)
    }

    /// Puts back the brightness the boost found, if it is on.
    @MainActor
    public mutating func end(on screen: ScreenBrightness) {
        guard let original else { return }
        screen.write(original)
        self.original = nil
    }

    /// Follows the app in and out of the foreground while a card is open. iOS
    /// keeps the brightness an app sets after the app has gone, until the
    /// phone locks, so it is put back as soon as the app stops being active,
    /// as for the Home Screen, the app switcher or Control Centre, and turned
    /// up again when it is active once more, if `enabled`.
    @MainActor
    public mutating func follow(_ phase: ScenePhase, enabled: Bool, on screen: ScreenBrightness) {
        if phase == .active {
            if enabled {
                start(on: screen)
            }
        } else {
            end(on: screen)
        }
    }
}

private struct ScreenBrightnessKey: EnvironmentKey {
    static let defaultValue = ScreenBrightness.live
}

public extension EnvironmentValues {
    var screenBrightness: ScreenBrightness {
        get { self[ScreenBrightnessKey.self] }
        set { self[ScreenBrightnessKey.self] = newValue }
    }
}
