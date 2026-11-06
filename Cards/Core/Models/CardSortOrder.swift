/// The orders the Cards tab can show the cards in (CARD-11). The choice is kept
/// on the device under `DeviceSettings.cardSortOrderKey`, so the raw values are
/// stored and never change.
public enum CardSortOrder: String, CaseIterable, Identifiable, Sendable {
    /// The card opened most recently first, then the cards never opened, in custom order.
    case lastViewed
    /// The order set by dragging: each card's `order`.
    case custom
    /// The cards with places, nearest first, then the rest in custom order.
    case location

    public var id: Self { self }
}
