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
    private func deliver() {
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let next = state.withLock { state -> Data? in
            guard let latest = state.latest, latest != state.sent else { return nil }
            state.sent = latest
            return latest
        }
        guard let next else { return }
        let sentAt = Date()
        do {
            if next.count <= WatchSnapshot.contextLimit {
                try session.updateApplicationContext([WatchSnapshot.cardsKey: next, WatchSnapshot.sentAtKey: sentAt])
            } else {
                session.outstandingFileTransfers.forEach { $0.cancel() }
                let file = FileManager.default.temporaryDirectory.appending(path: "watch-cards-\(UUID().uuidString)")
                try next.write(to: file)
                session.transferFile(file, metadata: [WatchSnapshot.sentAtKey: sentAt])
            }
        } catch {
            // Sent again with the next change of cards, or the next launch.
            state.withLock { state in
                if state.sent == next { state.sent = nil }
            }
            Self.logger.error("Could not send the cards to the watch: \(error.localizedDescription, privacy: .public)")
        }
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

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        if let error {
            Self.logger.error("The cards' file did not reach the watch: \(error.localizedDescription, privacy: .public)")
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
