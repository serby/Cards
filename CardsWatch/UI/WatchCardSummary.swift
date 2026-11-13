/// A card in the watch's list (WATCH-2): its colour, icon and name, and how
/// far away its nearest place is when the watch knows where you are.
struct WatchCardSummary: Identifiable, Hashable, Sendable {
    /// The card's code.
    let id: String
    let name: String
    let color: CardColor
    /// An SF Symbol's name, or nil for none.
    let icon: String?
    /// Nil while where you are is unknown, or the card has no places.
    let proximity: CardProximity?
}
