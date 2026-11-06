import Foundation

/// An SF Symbol a card can carry (CARD-12), with the words VoiceOver says for it
/// in the picker. A card stores only `name`, in `CardItem.symbol`.
public struct CardSymbol: Hashable, Identifiable, Sendable {
    /// The SF Symbol's name, as stored with the card.
    public let name: String
    /// What the symbol shows, for the picker's VoiceOver label.
    public let label: String

    public var id: String { name }

    public init(_ name: String, label: String) {
        self.name = name
        self.label = label
    }
}

public extension CardSymbol {
    /// The symbols the picker offers, chosen for loyalty and membership cards and
    /// grouped by what they stand for. Every one is in SF Symbols 6, so iOS 18
    /// draws it; a test checks. Stored names never change, so remove a symbol
    /// from this list rather than renaming it.
    static let all: [Self] = [
        // Shopping
        Self("basket.fill", label: "Basket"),
        Self("cart.fill", label: "Trolley"),
        Self("bag.fill", label: "Shopping bag"),
        Self("tag.fill", label: "Price tag"),
        Self("gift.fill", label: "Gift"),
        Self("tshirt.fill", label: "T-shirt"),
        // Food and drink
        Self("cup.and.saucer.fill", label: "Coffee cup"),
        Self("mug.fill", label: "Mug"),
        Self("takeoutbag.and.cup.and.straw.fill", label: "Takeaway"),
        Self("fork.knife", label: "Restaurant"),
        Self("birthday.cake.fill", label: "Cake"),
        Self("wineglass.fill", label: "Wine glass"),
        // Getting about
        Self("fuelpump.fill", label: "Fuel pump"),
        Self("car.fill", label: "Car"),
        Self("airplane", label: "Aeroplane"),
        Self("bus.fill", label: "Bus"),
        Self("bed.double.fill", label: "Hotel"),
        Self("suitcase.fill", label: "Suitcase"),
        // Fitness
        Self("dumbbell.fill", label: "Dumbbell"),
        Self("figure.run", label: "Running"),
        Self("figure.pool.swim", label: "Swimming"),
        Self("figure.climbing", label: "Climbing"),
        Self("bicycle", label: "Bicycle"),
        // Health
        Self("cross.case.fill", label: "First aid"),
        Self("pills.fill", label: "Pharmacy"),
        Self("heart.fill", label: "Heart"),
        // Books and going out
        Self("book.fill", label: "Book"),
        Self("books.vertical.fill", label: "Library"),
        Self("ticket.fill", label: "Ticket"),
        Self("film.fill", label: "Cinema"),
        Self("theatermasks.fill", label: "Theatre"),
        // Pets, home and garden
        Self("pawprint.fill", label: "Pets"),
        Self("leaf.fill", label: "Garden"),
        Self("hammer.fill", label: "DIY"),
        Self("scissors", label: "Hairdresser")
    ]

    /// The picker's label for a stored symbol name: nil for none, and the name
    /// itself for a symbol this build doesn't list (from a newer build).
    static func label(for name: String?) -> String? {
        guard let name else { return nil }
        return all.first { $0.name == name }?.label ?? name
    }
}
