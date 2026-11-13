import Foundation
import WatchConnectivity

/// The watch's end of WatchConnectivity (WATCH-1): hands on each snapshot of
/// the cards the iPhone sends, as the application context or as a file, with
/// when the phone sent it. `CardsWatchApp` makes one and activates it at
/// launch, which is wiring, as handing iOS a delegate is on the phone.
final class PhoneLink: NSObject, WCSessionDelegate, Sendable {
    private let receive: @MainActor @Sendable (Data, Date) -> Void

    init(receive: @escaping @MainActor @Sendable (Data, Date) -> Void) {
        self.receive = receive
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// The context last received is kept by the system, so anything that came
    /// while the app was not running is read here.
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        deliver(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(applicationContext)
    }

    /// A snapshot too large for the context. The file goes once this returns,
    /// so it is read now.
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let sentAt = file.metadata?[WatchSnapshot.sentAtKey] as? Date,
              let encoded = try? Data(contentsOf: file.fileURL)
        else { return }
        hand(encoded, sentAt)
    }

    private func deliver(_ context: [String: Any]) {
        guard let encoded = context[WatchSnapshot.cardsKey] as? Data,
              let sentAt = context[WatchSnapshot.sentAtKey] as? Date
        else { return }
        hand(encoded, sentAt)
    }

    private func hand(_ encoded: Data, _ sentAt: Date) {
        let receive = receive
        Task { @MainActor in
            receive(encoded, sentAt)
        }
    }
}
