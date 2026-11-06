import SwiftUI

@MainActor
let cardIconPickerStory = Story(
    id: "card-icon-picker",
    title: "CardIconPicker",
    section: "Components",
    knobs: [
        IconKnob.knob("basket.fill"),
        .options("Colour", CardColor.allNames, CardColor.teal.rawValue)
    ],
    gallery: [
        (
            name: "On teal",
            view: AnyView(
                Stateful(String?("cup.and.saucer.fill")) { icon in
                    CardIconPicker(selection: icon, color: .teal)
                }
                .padding()
            )
        ),
        (
            name: "None chosen, default colour",
            view: AnyView(
                Stateful(String?.none) { icon in
                    CardIconPicker(selection: icon)
                }
                .padding()
            )
        ),
        (
            name: "On yellow, dark ink",
            view: AnyView(
                Stateful(String?("fuelpump.fill")) { icon in
                    CardIconPicker(selection: icon, color: .yellow)
                }
                .padding()
            )
        )
    ]
) { knobs in
    AnyView(
        ScrollView {
            CardIconPicker(selection: knobs.iconBinding, color: .named(knobs.option("Colour")))
                .padding()
        }
    )
}

/// The knob choosing a card's icon, shared by every story that shows one.
enum IconKnob {
    static let name = "Icon"
    static let none = "None"

    static func knob(_ selected: String?) -> StoryKnob {
        .options(name, [none] + CardIcon.all.map(\.name), selected ?? none)
    }
}

extension KnobValues {
    /// The icon the shared knob names; nil for None.
    var icon: String? {
        let name = option(IconKnob.name)
        return name == IconKnob.none ? nil : name
    }

    var iconBinding: Binding<String?> {
        Binding(get: { self.icon }, set: { self.select($0 ?? IconKnob.none, for: IconKnob.name) })
    }
}
