import Foundation
import Observation
import OSLog

/// The cards on the watch (WATCH-1): the last the iPhone sent, read from the
/// kept file when the app starts and replaced whenever a newer snapshot
/// arrives. The phone sends a snapshot as the application context or, when it
/// is large, as a file, so the two can arrive out of order; the one the phone
/// sent last always wins. Created once by `CardsWatchApp`.
@MainActor
@Observable
final class WatchCards {
    /// In the iPhone list's own order (CARD-7).
    private(set) var cards: [WatchCard]
    /// The Distances choice on the phone (SET-4).
    private(set) var distanceUnits: DistanceUnits
    /// When the phone sent the cards shown, or nil before any have arrived.
    @ObservationIgnored private var sentAt: Date?
    @ObservationIgnored private let file: WatchSnapshotFile

    private static let logger = Logger(subsystem: "net.serby.Cards.watchkitapp", category: "WatchCards")

    init(file: WatchSnapshotFile) {
        self.file = file
        let kept = file.read()
        cards = kept?.snapshot.cards ?? []
        distanceUnits = kept?.snapshot.distanceUnits ?? .automatic
        sentAt = kept?.sentAt
    }

    func card(_ code: String) -> WatchCard? {
        cards.first { $0.code == code }
    }

    /// Takes the cards the phone sent at `sentAt`, encoded as they travel
    /// (`WatchSnapshot.encoded()`), and keeps them for next time, unless the
    /// cards here are as new.
    func receive(_ encoded: Data, sentAt: Date) {
        if let shown = self.sentAt, shown >= sentAt { return }
        do {
            let snapshot = try WatchSnapshot(encoded: encoded)
            cards = snapshot.cards
            distanceUnits = snapshot.distanceUnits
            self.sentAt = sentAt
            file.write(KeptSnapshot(sentAt: sentAt, snapshot: snapshot))
        } catch {
            Self.logger.error("Could not read the cards from the iPhone: \(error.localizedDescription, privacy: .public)")
        }
    }
}
