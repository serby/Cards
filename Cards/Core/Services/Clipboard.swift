import SwiftUI
import UIKit

/// The system clipboard, for copying a card's code and pasting an export,
/// injected so nothing but the live value reaches the pasteboard.
public struct Clipboard: Sendable {
    /// The text on the clipboard, if there is any.
    public var read: @MainActor @Sendable () -> String?
    /// Replaces the clipboard with `text`.
    public var write: @MainActor @Sendable (String) -> Void

    public init(
        read: @escaping @MainActor @Sendable () -> String?,
        write: @escaping @MainActor @Sendable (String) -> Void
    ) {
        self.read = read
        self.write = write
    }
}

public extension Clipboard {
    /// The general pasteboard, shared with other apps.
    static let live = Self(
        read: { UIPasteboard.general.string },
        write: { UIPasteboard.general.string = $0 }
    )
}

private struct ClipboardKey: EnvironmentKey {
    static let defaultValue = Clipboard.live
}

public extension EnvironmentValues {
    var clipboard: Clipboard {
        get { self[ClipboardKey.self] }
        set { self[ClipboardKey.self] = newValue }
    }
}
