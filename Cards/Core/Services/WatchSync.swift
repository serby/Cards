import Foundation
import OSLog
import SwiftUI
import Synchronization
import WatchConnectivity

/// Sends the cards to the Card Barcodes app on the Apple Watch paired with this
/// iPhone (WATCH-1), injected so only the live value reaches WatchConnectivity.
public struct WatchSync: Sendable {
    /// Hands the watch the cards as they are now. They go once a watch with
    /// the app on it is paired and the session is active, and not at all if
    /// they are what the watch was last sent. A failure is logged.
    public var send: @Sendable (WatchSnapshot) -> Void

    public init(send: @escaping @Sendable (WatchSnapshot) -> Void) {
        self.send = send
    }
}

public extension WatchSync {
    /// The device's WatchConnectivity session, activated the first time this
    /// is used. Does nothing where no watch can pair, such as on an iPad.
    static let live: Self = {
        guard WCSession.isSupported() else { return Self { _ in } }
        let link = WatchLink(session: .default)
        return Self(send: link.send)
    }()
}

/// The live client's session: the newest cards, waiting until the watch can
/// take them, and what it was last sent, so the same cards never go twice.
///
/// A snapshot up to `WatchSnapshot.contextLimit` goes as the application
/// context, which keeps only the newest and reaches the watch app even while it
/// is not running. A larger one, from hundreds of cards or very long codes,
/// goes as a file instead, after cancelling any file still on its way, and the
/// watch keeps whichever of the two the phone sent last (`sentAtKey`).
///
/// WatchConnectivity calls its delegate on a queue of its own, and its session
/// may be used from any thread, so the state sits behind a lock rather than
/// on an actor.
private final class WatchLink: NSObject, WCSessionDelegate, @unchecked Sendable {
    private struct State {
        /// The newest snapshot, encoded, whether or not it has gone.
        var latest: Data?
        /// What the watch was last sent, since this launch or this watch.
        var sent: Data?
        /// The file carrying `sent`, while it is on its way as one.
        var sentFile: URL?
    }

    private let session: WCSession
    private let state = Mutex(State())
    private static let logger = Logger(subsystem: "net.serby.Cards", category: "WatchSync")

    init(session: WCSession) {
        self.session = session
        super.init()
        session.delegate = self
        session.activate()
    }

    func send(_ snapshot: WatchSnapshot) {
        do {
            let encoded = try snapshot.encoded()
            state.withLock { $0.latest = encoded }
            deliver()
        } catch {
            Self.logger.error("Could not encode the cards for the watch: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Sends the newest snapshot if the watch can take it and has not had it.
    /// It is claimed, stamped and sent under the lock, so two deliveries at
    /// once, from the main thread and WatchConnectivity's queue, can never send
    /// an older snapshot with a newer time, which the watch would keep.
    private func deliver() {
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        state.withLock { state in
            guard let latest = state.latest, latest != state.sent else { return }
            do {
                state.sentFile = try send(latest, at: Date())
                state.sent = latest
            } catch {
                // Sent again with the next change of cards, or the next launch.
                Self.logger.error("Could not send the cards to the watch: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Sends `snapshot`, as the application context or, when it is too big for
    /// one, as a file, whose address it gives back. A file still on its way
    /// is older either way, so it is cancelled.
    private func send(_ snapshot: Data, at sentAt: Date) throws -> URL? {
        session.outstandingFileTransfers.forEach { $0.cancel() }
        if snapshot.count <= WatchSnapshot.contextLimit {
            try session.updateApplicationContext([WatchSnapshot.cardsKey: snapshot, WatchSnapshot.sentAtKey: sentAt])
            return nil
        }
        let file = FileManager.default.temporaryDirectory.appending(path: "watch-cards-\(UUID().uuidString)")
        try snapshot.write(to: file)
        session.transferFile(file, metadata: [WatchSnapshot.sentAtKey: sentAt])
        return file
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error {
            Self.logger.error("The watch session did not activate: \(error.localizedDescription, privacy: .public)")
        }
        deliver()
    }

    /// The app was installed on the watch or taken off it, or a watch paired
    /// or unpaired; a watch app that has just arrived has had nothing yet.
    func sessionWatchStateDidChange(_ session: WCSession) {
        if !session.isPaired || !session.isWatchAppInstalled {
            state.withLock { $0.sent = nil }
        }
        deliver()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Another watch was chosen: it has had nothing yet, and the session must
    /// be activated again to reach it.
    func sessionDidDeactivate(_ session: WCSession) {
        state.withLock { $0.sent = nil }
        session.activate()
    }

    /// A file that carried the newest snapshot and failed is sent again; one
    /// cancelled for a newer snapshot is not.
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
        let file = fileTransfer.file.fileURL
        try? FileManager.default.removeItem(at: file)
        let failedNewest = state.withLock { state in
            guard state.sentFile == file else { return false }
            state.sentFile = nil
            if error != nil { state.sent = nil }
            return error != nil
        }
        if let error {
            Self.logger.error("The cards' file did not reach the watch: \(error.localizedDescription, privacy: .public)")
        }
        if failedNewest {
            deliver()
        }
    }
}

private struct WatchSyncKey: EnvironmentKey {
    static let defaultValue = WatchSync.live
}

public extension EnvironmentValues {
    var watchSync: WatchSync {
        get { self[WatchSyncKey.self] }
        set { self[WatchSyncKey.self] = newValue }
    }
}
