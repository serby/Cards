import SwiftUI

@MainActor
let cardSymbolPickerStory = Story(
    id: "card-symbol-picker",
    title: "CardSymbolPicker",
    section: "Components",
    knobs: [
        SymbolKnob.knob("basket.fill"),
        .options("Colour", CardColor.allNames, CardColor.teal.rawValue)
    ],
    gallery: [
        (
            name: "On teal",
            view: AnyView(
                Stateful(String?("cup.and.saucer.fill")) { symbol in
                    CardSymbolPicker(selection: symbol, color: .teal)
                }
                .padding()
            )
        ),
        (
            name: "None chosen, default colour",
            view: AnyView(
                Stateful(String?.none) { symbol in
                    CardSymbolPicker(selection: symbol)
                }
                .padding()
            )
        ),
        (
            name: "On yellow, dark ink",
            view: AnyView(
                Stateful(String?("fuelpump.fill")) { symbol in
                    CardSymbolPicker(selection: symbol, color: .yellow)
                }
                .padding()
            )
        )
    ]
) { knobs in
    AnyView(
        ScrollView {
            CardSymbolPicker(selection: knobs.symbolBinding, color: .named(knobs.option("Colour")))
                .padding()
        }
    )
}

/// The knob choosing a card's symbol, shared by every story that shows one.
enum SymbolKnob {
    static let name = "Symbol"
    static let none = "None"

    static func knob(_ selected: String?) -> StoryKnob {
        .options(name, [none] + CardSymbol.all.map(\.name), selected ?? none)
    }
}

extension KnobValues {
    /// The symbol the shared knob names; nil for None.
    var symbol: String? {
        let name = option(SymbolKnob.name)
        return name == SymbolKnob.none ? nil : name
    }

    var symbolBinding: Binding<String?> {
        Binding(get: { self.symbol }, set: { self.select($0 ?? SymbolKnob.none, for: SymbolKnob.name) })
    }
}
