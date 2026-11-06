import Foundation

/// An icon a card can carry (CARD-12), drawn from SF Symbols, with the words
/// VoiceOver says for it in the picker. A card stores only `name`, in `CardItem.icon`.
///
/// Two icons are the same icon when their names are: the name is what a card
/// stores, and the label is only how it is said.
public struct CardIcon: Hashable, Identifiable, Sendable {
    /// The SF Symbol's name, as stored with the card.
    public let name: String
    /// What the icon shows, for the picker's VoiceOver label, in the language
    /// it is shown in.
    public let label: LocalizedStringResource

    public var id: String { name }

    public init(_ name: String, label: LocalizedStringResource) {
        self.name = name
        self.label = label
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

public extension CardIcon {
    /// Icons that stand for one kind of card, under a heading in the picker.
    struct Group: Hashable, Identifiable, Sendable {
        /// The picker's heading for the group.
        public let title: LocalizedStringResource
        public let icons: [CardIcon]

        /// The heading's English, which no two groups share.
        public var id: String { title.key }

        public init(_ title: LocalizedStringResource, _ icons: [CardIcon]) {
            self.title = title
            self.icons = icons
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id && lhs.icons == rhs.icons
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(icons)
        }
    }

    /// The icons the picker offers, chosen for loyalty and membership cards and
    /// grouped by what they stand for. Every one is in SF Symbols 6, so iOS 18
    /// draws it; a test checks. Stored names never change, so remove an icon
    /// from this list rather than renaming it. Moving one to another group is fine.
    static let groups: [Group] = [
        Group(LocalizedStringResource("Shopping", comment: "Heading in the card icon picker over icons for shops."), [
            Self("basket.fill", label: LocalizedStringResource(
                "Basket", comment: "Card icon picker, read by VoiceOver: a shopping basket."
            )),
            Self("cart.fill", label: LocalizedStringResource(
                "Trolley", comment: "Card icon picker, read by VoiceOver: a supermarket trolley, or shopping cart."
            )),
            Self("bag.fill", label: LocalizedStringResource(
                "Shopping bag", comment: "Card icon picker, read by VoiceOver: a shopping bag."
            )),
            Self("storefront.fill", label: LocalizedStringResource(
                "Shop", comment: "Card icon picker, read by VoiceOver: a shop front. A noun."
            )),
            Self("tag.fill", label: LocalizedStringResource(
                "Price tag", comment: "Card icon picker, read by VoiceOver: a price tag."
            )),
            Self("gift.fill", label: LocalizedStringResource(
                "Gift", comment: "Card icon picker, read by VoiceOver: a wrapped present. A noun."
            )),
            Self("tshirt.fill", label: LocalizedStringResource(
                "T-shirt", comment: "Card icon picker, read by VoiceOver: a T-shirt, for clothes shops."
            ))
        ]),
        Group(LocalizedStringResource("Food and drink", comment: "Heading in the card icon picker over icons for cafés and restaurants."), [
            Self("cup.and.saucer.fill", label: LocalizedStringResource(
                "Coffee cup", comment: "Card icon picker, read by VoiceOver: a cup on a saucer, for cafés."
            )),
            Self("mug.fill", label: LocalizedStringResource(
                "Mug", comment: "Card icon picker, read by VoiceOver: a mug."
            )),
            Self("takeoutbag.and.cup.and.straw.fill", label: LocalizedStringResource(
                "Takeaway", comment: "Card icon picker, read by VoiceOver: a bag and a cup of takeaway food. A noun."
            )),
            Self("fork.knife", label: LocalizedStringResource(
                "Restaurant", comment: "Card icon picker, read by VoiceOver: a knife and fork, for restaurants."
            )),
            Self("birthday.cake.fill", label: LocalizedStringResource(
                "Cake", comment: "Card icon picker, read by VoiceOver: a cake, for bakeries."
            )),
            Self("wineglass.fill", label: LocalizedStringResource(
                "Wine glass", comment: "Card icon picker, read by VoiceOver: a wine glass, for bars and wine shops."
            )),
            Self("carrot.fill", label: LocalizedStringResource(
                "Carrot", comment: "Card icon picker, read by VoiceOver: a carrot, for greengrocers."
            ))
        ]),
        Group(LocalizedStringResource("Health and beauty", comment: "Heading in the card icon picker over icons for health and beauty shops."), [
            Self("heart.fill", label: LocalizedStringResource(
                "Heart", comment: "Card icon picker, read by VoiceOver: a heart."
            )),
            Self("figure.mind.and.body", label: LocalizedStringResource(
                "Wellbeing", comment: "Card icon picker, read by VoiceOver: a person meditating, for wellbeing and yoga."
            )),
            Self("sparkles", label: LocalizedStringResource(
                "Beauty", comment: "Card icon picker, read by VoiceOver: sparkles, for beauty shops and salons."
            )),
            Self("eyeglasses", label: LocalizedStringResource(
                "Optician", comment: "Card icon picker, read by VoiceOver: a pair of glasses, for opticians."
            ))
        ]),
        Group(LocalizedStringResource("Pharmacy", comment: "Heading in the card icon picker over icons for pharmacies and doctors."), [
            Self("pills.fill", label: LocalizedStringResource(
                "Pharmacy", comment: "Card icon picker, read by VoiceOver: pills, for pharmacies."
            )),
            Self("cross.case.fill", label: LocalizedStringResource(
                "First aid", comment: "Card icon picker, read by VoiceOver: a first aid kit."
            )),
            Self("bandage.fill", label: LocalizedStringResource(
                "Plaster", comment: "Card icon picker, read by VoiceOver: a sticking plaster for a cut, or adhesive bandage."
            )),
            Self("stethoscope", label: LocalizedStringResource(
                "Doctor", comment: "Card icon picker, read by VoiceOver: a stethoscope, for doctors."
            ))
        ]),
        Group(LocalizedStringResource("Sport and fitness", comment: "Heading in the card icon picker over icons for gyms and sports clubs."), [
            Self("dumbbell.fill", label: LocalizedStringResource(
                "Dumbbell", comment: "Card icon picker, read by VoiceOver: a dumbbell, for gyms."
            )),
            Self("figure.run", label: LocalizedStringResource(
                "Running", comment: "Card icon picker, read by VoiceOver: a person running. The sport, a noun."
            )),
            Self("figure.pool.swim", label: LocalizedStringResource(
                "Swimming", comment: "Card icon picker, read by VoiceOver: a person swimming. The sport, a noun."
            )),
            Self("figure.climbing", label: LocalizedStringResource(
                "Climbing", comment: "Card icon picker, read by VoiceOver: a person climbing, for climbing walls. The sport, a noun."
            )),
            Self("bicycle", label: LocalizedStringResource(
                "Bicycle", comment: "Card icon picker, read by VoiceOver: a bicycle."
            )),
            Self("soccerball", label: LocalizedStringResource(
                "Football", comment: "Card icon picker, read by VoiceOver: a football, or soccer ball."
            )),
            Self("tennis.racket", label: LocalizedStringResource(
                "Tennis", comment: "Card icon picker, read by VoiceOver: a tennis racket."
            )),
            Self("figure.golf", label: LocalizedStringResource(
                "Golf", comment: "Card icon picker, read by VoiceOver: a person playing golf."
            ))
        ]),
        Group(LocalizedStringResource("Travel", comment: "Heading in the card icon picker over icons for travel, cars and hotels. A noun."), [
            Self("car.fill", label: LocalizedStringResource(
                "Car", comment: "Card icon picker, read by VoiceOver: a car."
            )),
            Self("fuelpump.fill", label: LocalizedStringResource(
                "Fuel pump", comment: "Card icon picker, read by VoiceOver: a fuel pump, for petrol stations."
            )),
            Self("parkingsign.circle.fill", label: LocalizedStringResource(
                "Parking", comment: "Card icon picker, read by VoiceOver: a parking sign, for car parks. A noun."
            )),
            Self("bus.fill", label: LocalizedStringResource(
                "Bus", comment: "Card icon picker, read by VoiceOver: a bus."
            )),
            Self("train.side.front.car", label: LocalizedStringResource(
                "Train", comment: "Card icon picker, read by VoiceOver: a train. A noun."
            )),
            Self("airplane", label: LocalizedStringResource(
                "Aeroplane", comment: "Card icon picker, read by VoiceOver: an aeroplane, for airlines."
            )),
            Self("bed.double.fill", label: LocalizedStringResource(
                "Hotel", comment: "Card icon picker, read by VoiceOver: a bed, for hotels."
            )),
            Self("suitcase.fill", label: LocalizedStringResource(
                "Suitcase", comment: "Card icon picker, read by VoiceOver: a suitcase."
            ))
        ]),
        Group(LocalizedStringResource("Books and libraries", comment: "Heading in the card icon picker over icons for bookshops and libraries."), [
            Self("book.fill", label: LocalizedStringResource(
                "Book", comment: "Card icon picker, read by VoiceOver: a book. A noun."
            )),
            Self("books.vertical.fill", label: LocalizedStringResource(
                "Library", comment: "Card icon picker, read by VoiceOver: books on a shelf, for libraries."
            )),
            Self("newspaper.fill", label: LocalizedStringResource(
                "Newspaper", comment: "Card icon picker, read by VoiceOver: a newspaper."
            )),
            Self("graduationcap.fill", label: LocalizedStringResource(
                "Education", comment: "Card icon picker, read by VoiceOver: a graduation cap, for schools and courses."
            ))
        ]),
        Group(LocalizedStringResource("Cinema and entertainment", comment: "Heading in the card icon picker over icons for cinemas and theatres."), [
            Self("film.fill", label: LocalizedStringResource(
                "Cinema", comment: "Card icon picker, read by VoiceOver: a strip of film, for cinemas."
            )),
            Self("ticket.fill", label: LocalizedStringResource(
                "Ticket", comment: "Card icon picker, read by VoiceOver: a ticket."
            )),
            Self("theatermasks.fill", label: LocalizedStringResource(
                "Theatre", comment: "Card icon picker, read by VoiceOver: theatre masks, for theatres."
            )),
            Self("building.columns.fill", label: LocalizedStringResource(
                "Museum", comment: "Card icon picker, read by VoiceOver: a building with columns, for museums."
            ))
        ]),
        Group(LocalizedStringResource("Music", comment: "Heading in the card icon picker over icons for music shops and venues."), [
            Self("music.note", label: LocalizedStringResource(
                "Music", comment: "Card icon picker, read by VoiceOver: a musical note."
            )),
            Self("headphones", label: LocalizedStringResource(
                "Headphones", comment: "Card icon picker, read by VoiceOver: a pair of headphones."
            )),
            Self("guitars.fill", label: LocalizedStringResource(
                "Guitar", comment: "Card icon picker, read by VoiceOver: a guitar."
            ))
        ]),
        Group(LocalizedStringResource("Gaming", comment: "Heading in the card icon picker over icons for games shops and arcades. A noun."), [
            Self("gamecontroller.fill", label: LocalizedStringResource(
                "Games", comment: "Card icon picker, read by VoiceOver: a game controller, for games shops."
            )),
            Self("dice.fill", label: LocalizedStringResource(
                "Dice", comment: "Card icon picker, read by VoiceOver: a pair of dice."
            )),
            Self("puzzlepiece.fill", label: LocalizedStringResource(
                "Puzzle", comment: "Card icon picker, read by VoiceOver: a jigsaw puzzle piece."
            ))
        ]),
        Group(LocalizedStringResource("Pets", comment: "Heading in the card icon picker over icons for pet shops and vets."), [
            Self("pawprint.fill", label: LocalizedStringResource(
                "Pets", comment: "Card icon picker, read by VoiceOver: a paw print, for pet shops."
            )),
            Self("dog.fill", label: LocalizedStringResource(
                "Dog", comment: "Card icon picker, read by VoiceOver: a dog."
            )),
            Self("cat.fill", label: LocalizedStringResource(
                "Cat", comment: "Card icon picker, read by VoiceOver: a cat."
            )),
            Self("fish.fill", label: LocalizedStringResource(
                "Fish", comment: "Card icon picker, read by VoiceOver: a fish. A noun."
            ))
        ]),
        Group(LocalizedStringResource("Home and garden", comment: "Heading in the card icon picker over icons for home shops and garden centres."), [
            Self("house.fill", label: LocalizedStringResource(
                "Home", comment: "Card icon picker, read by VoiceOver: a house, for home shops. A noun."
            )),
            Self("sofa.fill", label: LocalizedStringResource(
                "Furniture", comment: "Card icon picker, read by VoiceOver: a sofa, for furniture shops."
            )),
            Self("leaf.fill", label: LocalizedStringResource(
                "Garden", comment: "Card icon picker, read by VoiceOver: a leaf, for garden centres. A noun."
            )),
            Self("camera.macro", label: LocalizedStringResource(
                "Flowers", comment: "Card icon picker, read by VoiceOver: a flower, for florists."
            ))
        ]),
        Group(LocalizedStringResource("DIY and hardware", comment: "Heading in the card icon picker over icons for DIY shops (do it yourself)."), [
            Self("hammer.fill", label: LocalizedStringResource(
                "DIY", comment: "Card icon picker, read by VoiceOver: a hammer, for DIY shops. DIY means do it yourself."
            )),
            Self("wrench.and.screwdriver.fill", label: LocalizedStringResource(
                "Tools", comment: "Card icon picker, read by VoiceOver: a spanner and a screwdriver. A noun."
            )),
            Self("wrench.adjustable.fill", label: LocalizedStringResource(
                "Spanner", comment: "Card icon picker, read by VoiceOver: an adjustable spanner, or wrench."
            )),
            Self("paintbrush.fill", label: LocalizedStringResource(
                "Paintbrush", comment: "Card icon picker, read by VoiceOver: a paintbrush."
            ))
        ]),
        Group(LocalizedStringResource("Hairdressers and services", comment: "Heading in the card icon picker over icons for hair salons and such."), [
            Self("scissors", label: LocalizedStringResource(
                "Hairdresser", comment: "Card icon picker, read by VoiceOver: a pair of scissors, for hairdressers."
            )),
            Self("comb.fill", label: LocalizedStringResource(
                "Comb", comment: "Card icon picker, read by VoiceOver: a comb. A noun."
            )),
            Self("washer.fill", label: LocalizedStringResource(
                "Laundry", comment: "Card icon picker, read by VoiceOver: a washing machine, for launderettes and dry cleaners."
            )),
            Self("key.fill", label: LocalizedStringResource(
                "Keys", comment: "Card icon picker, read by VoiceOver: a key, for key cutters."
            ))
        ]),
        Group(LocalizedStringResource("Money and payments", comment: "Heading in the card icon picker over icons for money and gift cards."), [
            Self("creditcard.fill", label: LocalizedStringResource(
                "Payment card", comment: "Card icon picker, read by VoiceOver: a bank card."
            )),
            Self("giftcard.fill", label: LocalizedStringResource(
                "Gift card", comment: "Card icon picker, read by VoiceOver: a gift card."
            )),
            Self("sterlingsign.circle.fill", label: LocalizedStringResource(
                "Pound", comment: "Card icon picker, read by VoiceOver: the pound sign, £. The British currency, not the weight."
            )),
            Self("percent", label: LocalizedStringResource(
                "Discount", comment: "Card icon picker, read by VoiceOver: a percent sign, for discounts. A noun."
            )),
            Self("star.fill", label: LocalizedStringResource(
                "Star", comment: "Card icon picker, read by VoiceOver: a star. A noun."
            ))
        ]),
        Group(LocalizedStringResource("Kids and toys", comment: "Heading in the card icon picker over icons for toy shops and children's things."), [
            Self("teddybear.fill", label: LocalizedStringResource(
                "Teddy bear", comment: "Card icon picker, read by VoiceOver: a teddy bear."
            )),
            Self("balloon.fill", label: LocalizedStringResource(
                "Balloon", comment: "Card icon picker, read by VoiceOver: a balloon."
            )),
            Self("stroller.fill", label: LocalizedStringResource(
                "Pushchair", comment: "Card icon picker, read by VoiceOver: a pushchair, or baby stroller."
            ))
        ])
    ]

    /// Every icon the picker offers, in the picker's order.
    static let all: [Self] = groups.flatMap(\.icons)

    /// The picker's label for a stored icon name: nil for none, and the name
    /// itself for an icon this build doesn't list (from a newer build), which
    /// the catalogue has no entry for and so shows as it is.
    static func label(for name: String?) -> LocalizedStringResource? {
        guard let name else { return nil }
        return all.first { $0.name == name }?.label ?? LocalizedStringResource(String.LocalizationValue(name))
    }
}
