@testable import Cards
import Testing
import UIKit

/// The icons a card can carry (CARD-12).
struct CardIconTests {
    /// The tests run on the oldest iOS the app supports, so an icon that only
    /// exists in a newer SF Symbols release fails here rather than drawing nothing.
    @Test(arguments: CardIcon.all)
    func everyIconDraws(_ icon: CardIcon) {
        #expect(UIImage(systemName: icon.name) != nil, "\(icon.name) is not in this iOS")
    }

    @Test func namesAndLabelsAreUniqueAndSaySomething() {
        #expect(Set(CardIcon.all.map(\.name)).count == CardIcon.all.count)
        let labels = CardIcon.all.map { String(localized: $0.label) }
        #expect(Set(labels).count == CardIcon.all.count)
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect((70...80).contains(CardIcon.all.count))
    }

    /// The picker shows a heading per group, in the order CARD-12 lists them.
    @Test func theSpecsGroupsAreOfferedInOrder() {
        #expect(CardIcon.groups.map { String(localized: $0.title) } == [
            "Shopping", "Food and drink", "Health and beauty", "Pharmacy", "Sport and fitness", "Travel",
            "Books and libraries", "Cinema and entertainment", "Music", "Gaming", "Pets", "Home and garden",
            "DIY and hardware", "Hairdressers and services", "Money and payments", "Kids and toys"
        ])
        #expect(CardIcon.groups.allSatisfy { !$0.icons.isEmpty })
        #expect(CardIcon.all == CardIcon.groups.flatMap(\.icons))
    }

    @Test func theSpecsExamplesAreOffered() {
        let names = Set(CardIcon.all.map(\.name))
        for example in [
            "basket.fill", "cup.and.saucer.fill", "dumbbell.fill", "book.fill", "fuelpump.fill", "bag.fill",
            "train.side.front.car", "parkingsign.circle.fill", "airplane", "bed.double.fill", "stroller.fill"
        ] {
            #expect(names.contains(example))
        }
    }

    @Test func labelsForStoredNames() {
        #expect(CardIcon.label(for: nil) == nil)
        #expect(spoken("basket.fill") == "Basket")
        #expect(spoken("stroller.fill") == "Pushchair")
        // An icon from a newer build still has something to say.
        #expect(spoken("wand.and.stars") == "wand.and.stars")
    }

    private func spoken(_ name: String) -> String? {
        CardIcon.label(for: name).map { String(localized: $0) }
    }
}
