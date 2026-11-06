import Foundation

/// The test arrival notification (DEV-2): a card's own arrival alert, made by
/// `ArrivalPlan` as the real one is, at the card's first place, or at a place
/// called "Test" for a card with none.
enum TestArrival {
    /// How long after the tap it arrives, in seconds.
    static let delay: TimeInterval = 5
    /// What the place is called for a card with no places.
    static let placeholderName = "Test"

    /// Where the notification says you are.
    static func place(for card: ArrivalPlan.Card) -> CardLocation {
        card.locations.first ?? CardLocation(name: placeholderName, latitude: 0, longitude: 0)
    }

    /// The card's arrival alert under an identifier of its own: a place's real
    /// identifier would replace the arrival scheduled there, which would then
    /// not come back until the places to watch changed.
    static func alert(for card: ArrivalPlan.Card) -> ArrivalAlert {
        let real = ArrivalPlan.alert(for: ArrivalPlan.Arrival(card: card, location: place(for: card)))
        return ArrivalAlert(
            id: "test.\(UUID().uuidString)",
            title: real.title,
            body: real.body,
            code: real.code,
            barcodePNG: real.barcodePNG,
            place: real.place
        )
    }
}
