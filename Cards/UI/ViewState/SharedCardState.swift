import Foundation

/// What the "Add Card?" sheet shows for a share link (SHARE-3).
public enum SharedCardState: Hashable, Sendable {
    /// A card to add: its face, and the places it comes with.
    case new(CardDetail, places: [CardLocation])
    /// A card whose code is already in the app, which can be opened instead.
    case alreadyAdded(CardDetail, places: [CardLocation])
    /// A link that holds no card.
    case unreadable
}
