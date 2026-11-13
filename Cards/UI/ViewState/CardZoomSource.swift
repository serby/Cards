import Foundation

/// What a card's screen zooms up out of when it opens (CARD-4): the card's tile
/// in the grid, or the card for where you are above it (SET-3), which can show
/// the same card at once, so each has its own.
public struct CardZoomSource: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case tile
        case cardWhereYouAre
    }

    public let kind: Kind
    public let cardID: CardSummary.ID

    public init(_ kind: Kind, cardID: CardSummary.ID) {
        self.kind = kind
        self.cardID = cardID
    }
}
