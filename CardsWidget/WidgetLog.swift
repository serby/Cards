import CoreLocation
import Foundation
import os

/// A diagnostic trail of each widget reload: whether the widget may use your
/// location, what Core Location gave it and how old that was, and which card it
/// showed. Each line goes to the unified log and to the end of a file in the App
/// Group container, kept to its last lines, which a Mac reads off a phone with
/// `xcrun devicectl device copy from --domain-type appGroupDataContainer
/// --domain-identifier group.net.serby.Cards --source Library/widget-log.txt`. It holds
/// no coordinates.
struct WidgetLog: Sendable {
    var write: @Sendable (String) -> Void
}

extension WidgetLog {
    /// Under Library, as devicectl only copies from Library, Documents and tmp.
    static let fileName = "Library/widget-log.txt"
    static let maximumLines = 2_000

    static let silent = Self { _ in }

    static let live: Self = {
        let logger = Logger(subsystem: "net.serby.Cards", category: "Widget")
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)?
            .appending(path: fileName)
        // Reloads can overlap in the widget's process.
        let lock = OSAllocatedUnfairLock()
        return Self { message in
            // Private in the unified log, as lines name your cards and places.
            logger.notice("\(message, privacy: .private)")
            guard let url else { return }
            let line = "\(Date.now.formatted(Date.ISO8601FormatStyle(timeZone: .current))) \(message)"
            lock.withLock {
                let earlier = (try? String(contentsOf: url, encoding: .utf8))?
                    .split(separator: "\n")
                    .suffix(maximumLines - 1)
                    .map(String.init) ?? []
                try? ((earlier + [line]).joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }()
}

extension CLLocation {
    /// How old and how accurate this fix is, for the widget's log.
    var logDescription: String {
        "\(Int(-timestamp.timeIntervalSinceNow)) s old, ±\(Int(horizontalAccuracy)) m"
    }
}
