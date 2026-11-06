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
        #expect(Set(CardIcon.all.map(\.label)).count == CardIcon.all.count)
        #expect(CardIcon.all.allSatisfy { !$0.label.isEmpty })
        #expect((30...40).contains(CardIcon.all.count))
    }

    @Test func theSpecsExamplesAreOffered() {
        let names = Set(CardIcon.all.map(\.name))
        for example in ["basket.fill", "cup.and.saucer.fill", "dumbbell.fill", "book.fill", "fuelpump.fill", "bag.fill"] {
            #expect(names.contains(example))
        }
    }

    @Test func labelsForStoredNames() {
        #expect(CardIcon.label(for: nil) == nil)
        #expect(CardIcon.label(for: "basket.fill") == "Basket")
        // An icon from a newer build still has something to say.
        #expect(CardIcon.label(for: "sparkles") == "sparkles")
    }
}
