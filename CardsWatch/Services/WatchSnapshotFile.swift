import Foundation
import OSLog

/// The cards the watch last received, with when the phone sent them.
struct KeptSnapshot: Codable, Hashable, Sendable {
    let sentAt: Date
    let snapshot: WatchSnapshot
}

/// The last cards the iPhone sent, kept in a file in the watch app's own
/// container, so the app opens on them at once and works with the phone out of
/// reach (WATCH-1). Injected, so only the live value touches the file system.
struct WatchSnapshotFile: Sendable {
    /// The cards last kept, or nil before any have arrived or if they cannot be read.
    var read: @Sendable () -> KeptSnapshot?
    /// Keeps `snapshot` in place of the last. A failure is logged.
    var write: @Sendable (KeptSnapshot) -> Void
}

extension WatchSnapshotFile {
    /// `watch-cards.json` in the app's Application Support folder.
    static let live = file(at: URL.applicationSupportDirectory.appending(path: "watch-cards.json"))

    /// The snapshot kept as JSON at `url`, its folder made when first needed.
    static func file(at url: URL) -> Self {
        Self(
            read: {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(KeptSnapshot.self, from: data)
            },
            write: { kept in
                do {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try JSONEncoder().encode(kept).write(to: url, options: .atomic)
                } catch {
                    logger.error("Could not keep the cards: \(error.localizedDescription, privacy: .public)")
                }
            }
        )
    }

    private static let logger = Logger(subsystem: "net.serby.Cards.watchkitapp", category: "WatchSnapshotFile")
}
