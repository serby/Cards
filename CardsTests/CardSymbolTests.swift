@testable import Cards
import Testing
import UIKit

/// The symbols a card can carry (CARD-12).
struct CardSymbolTests {
    /// The tests run on the oldest iOS the app supports, so a symbol that only
    /// exists in a newer SF Symbols release fails here rather than drawing nothing.
    @Test(arguments: CardSymbol.all)
    func everySymbolDraws(_ symbol: CardSymbol) {
        #expect(UIImage(systemName: symbol.name) != nil, "\(symbol.name) is not in this iOS")
    }

    @Test func namesAndLabelsAreUniqueAndSaySomething() {
        #expect(Set(CardSymbol.all.map(\.name)).count == CardSymbol.all.count)
        #expect(Set(CardSymbol.all.map(\.label)).count == CardSymbol.all.count)
        #expect(CardSymbol.all.allSatisfy { !$0.label.isEmpty })
        #expect((30...40).contains(CardSymbol.all.count))
    }

    @Test func theSpecsExamplesAreOffered() {
        let names = Set(CardSymbol.all.map(\.name))
        for example in ["basket.fill", "cup.and.saucer.fill", "dumbbell.fill", "book.fill", "fuelpump.fill", "bag.fill"] {
            #expect(names.contains(example))
        }
    }

    @Test func labelsForStoredNames() {
        #expect(CardSymbol.label(for: nil) == nil)
        #expect(CardSymbol.label(for: "basket.fill") == "Basket")
        // A symbol from a newer build still has something to say.
        #expect(CardSymbol.label(for: "sparkles") == "sparkles")
    }
}
