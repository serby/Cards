import Foundation

/// An arrival notification as plain values: what it says, the barcode attached
/// and the place that triggers it. `ArrivalPlan` writes it and the notification
/// client turns it into a location-triggered request.
public struct ArrivalAlert: Hashable, Sendable {
    /// The `userInfo` key that carries the card's code, so a tap can open the card.
    public static let codeKey = "code"

    /// The request's identifier, one per place, so a place is never watched twice.
    public let id: String
    public let title: String
    public let body: String
    /// The card's code, which also groups the card's notifications together.
    public let code: String
    /// The barcode as an image on white, attached to the notification; nil when
    /// the code cannot be drawn.
    public let barcodePNG: Data?
    /// The circle that triggers the notification on entry.
    public let place: CardLocation

    public init(id: String, title: String, body: String, code: String, barcodePNG: Data?, place: CardLocation) {
        self.id = id
        self.title = title
        self.body = body
        self.code = code
        self.barcodePNG = barcodePNG
        self.place = place
    }
}
