import SwiftUI

@MainActor
let cardIconPickerStory = Story(
    id: "card-icon-picker",
    title: "CardIconPicker",
    section: "Components",
    // Each variant is taller than the screen, so a list would not show them side by side.
    galleryLayout: .oneAtATime,
    knobs: [
        IconKnob.knob("basket.fill"),
        .options("Colour", CardColor.allNames, CardColor.teal.rawValue)
    ],
    gallery: [
        (name: "On teal", view: iconPicker("cup.and.saucer.fill", color: .teal)),
        (name: "None chosen, default colour", view: iconPicker(nil, color: .standard)),
        (name: "On yellow, dark ink", view: iconPicker("fuelpump.fill", color: .yellow))
    ]
) { knobs in
    AnyView(
        ScrollView {
            CardIconPicker(selection: knobs.iconBinding, color: .named(knobs.option("Colour")))
                .padding()
        }
    )
}

/// A gallery variant: the picker, scrolling, with `icon` chosen on `color`.
@MainActor
private func iconPicker(_ icon: String?, color: CardColor) -> AnyView {
    AnyView(
        ScrollView {
            Stateful(icon) { selection in
                CardIconPicker(selection: selection, color: color)
            }
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
