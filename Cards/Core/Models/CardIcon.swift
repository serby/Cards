import Foundation

/// An icon a card can carry (CARD-12), drawn from SF Symbols, with the words
/// VoiceOver says for it in the picker. A card stores only `name`, in `CardItem.icon`.
public struct CardIcon: Hashable, Identifiable, Sendable {
    /// The SF Symbol's name, as stored with the card.
    public let name: String
    /// What the icon shows, for the picker's VoiceOver label.
    public let label: String

    public var id: String { name }

    public init(_ name: String, label: String) {
        self.name = name
        self.label = label
    }
}

public extension CardIcon {
    /// Icons that stand for one kind of card, under a heading in the picker.
    struct Group: Hashable, Identifiable, Sendable {
        /// The picker's heading for the group.
        public let title: String
        public let icons: [CardIcon]

        public var id: String { title }

        public init(_ title: String, _ icons: [CardIcon]) {
            self.title = title
            self.icons = icons
        }
    }

    /// The icons the picker offers, chosen for loyalty and membership cards and
    /// grouped by what they stand for. Every one is in SF Symbols 6, so iOS 18
    /// draws it; a test checks. Stored names never change, so remove an icon
    /// from this list rather than renaming it. Moving one to another group is fine.
    static let groups: [Group] = [
        Group("Shopping", [
            Self("basket.fill", label: "Basket"),
            Self("cart.fill", label: "Trolley"),
            Self("bag.fill", label: "Shopping bag"),
            Self("storefront.fill", label: "Shop"),
            Self("tag.fill", label: "Price tag"),
            Self("gift.fill", label: "Gift"),
            Self("tshirt.fill", label: "T-shirt")
        ]),
        Group("Food and drink", [
            Self("cup.and.saucer.fill", label: "Coffee cup"),
            Self("mug.fill", label: "Mug"),
            Self("takeoutbag.and.cup.and.straw.fill", label: "Takeaway"),
            Self("fork.knife", label: "Restaurant"),
            Self("birthday.cake.fill", label: "Cake"),
            Self("wineglass.fill", label: "Wine glass"),
            Self("carrot.fill", label: "Carrot")
        ]),
        Group("Health and beauty", [
            Self("heart.fill", label: "Heart"),
            Self("figure.mind.and.body", label: "Wellbeing"),
            Self("sparkles", label: "Beauty"),
            Self("eyeglasses", label: "Optician")
        ]),
        Group("Pharmacy", [
            Self("pills.fill", label: "Pharmacy"),
            Self("cross.case.fill", label: "First aid"),
            Self("bandage.fill", label: "Plaster"),
            Self("stethoscope", label: "Doctor")
        ]),
        Group("Sport and fitness", [
            Self("dumbbell.fill", label: "Dumbbell"),
            Self("figure.run", label: "Running"),
            Self("figure.pool.swim", label: "Swimming"),
            Self("figure.climbing", label: "Climbing"),
            Self("bicycle", label: "Bicycle"),
            Self("soccerball", label: "Football"),
            Self("tennis.racket", label: "Tennis"),
            Self("figure.golf", label: "Golf")
        ]),
        Group("Travel", [
            Self("car.fill", label: "Car"),
            Self("fuelpump.fill", label: "Fuel pump"),
            Self("parkingsign.circle.fill", label: "Parking"),
            Self("bus.fill", label: "Bus"),
            Self("train.side.front.car", label: "Train"),
            Self("airplane", label: "Aeroplane"),
            Self("bed.double.fill", label: "Hotel"),
            Self("suitcase.fill", label: "Suitcase")
        ]),
        Group("Books and libraries", [
            Self("book.fill", label: "Book"),
            Self("books.vertical.fill", label: "Library"),
            Self("newspaper.fill", label: "Newspaper"),
            Self("graduationcap.fill", label: "Education")
        ]),
        Group("Cinema and entertainment", [
            Self("film.fill", label: "Cinema"),
            Self("ticket.fill", label: "Ticket"),
            Self("theatermasks.fill", label: "Theatre"),
            Self("building.columns.fill", label: "Museum")
        ]),
        Group("Music", [
            Self("music.note", label: "Music"),
            Self("headphones", label: "Headphones"),
            Self("guitars.fill", label: "Guitar")
        ]),
        Group("Gaming", [
            Self("gamecontroller.fill", label: "Games"),
            Self("dice.fill", label: "Dice"),
            Self("puzzlepiece.fill", label: "Puzzle")
        ]),
        Group("Pets", [
            Self("pawprint.fill", label: "Pets"),
            Self("dog.fill", label: "Dog"),
            Self("cat.fill", label: "Cat"),
            Self("fish.fill", label: "Fish")
        ]),
        Group("Home and garden", [
            Self("house.fill", label: "Home"),
            Self("sofa.fill", label: "Furniture"),
            Self("leaf.fill", label: "Garden"),
            Self("camera.macro", label: "Flowers")
        ]),
        Group("DIY and hardware", [
            Self("hammer.fill", label: "DIY"),
            Self("wrench.and.screwdriver.fill", label: "Tools"),
            Self("wrench.adjustable.fill", label: "Spanner"),
            Self("paintbrush.fill", label: "Paintbrush")
        ]),
        Group("Hairdressers and services", [
            Self("scissors", label: "Hairdresser"),
            Self("comb.fill", label: "Comb"),
            Self("washer.fill", label: "Laundry"),
            Self("key.fill", label: "Keys")
        ]),
        Group("Money and payments", [
            Self("creditcard.fill", label: "Payment card"),
            Self("giftcard.fill", label: "Gift card"),
            Self("sterlingsign.circle.fill", label: "Pound"),
            Self("percent", label: "Discount"),
            Self("star.fill", label: "Star")
        ]),
        Group("Kids and toys", [
            Self("teddybear.fill", label: "Teddy bear"),
            Self("balloon.fill", label: "Balloon"),
            Self("stroller.fill", label: "Pushchair")
        ])
    ]

    /// Every icon the picker offers, in the picker's order.
    static let all: [Self] = groups.flatMap(\.icons)

    /// The picker's label for a stored icon name: nil for none, and the name
    /// itself for an icon this build doesn't list (from a newer build).
    static func label(for name: String?) -> String? {
        guard let name else { return nil }
        return all.first { $0.name == name }?.label ?? name
    }
}
