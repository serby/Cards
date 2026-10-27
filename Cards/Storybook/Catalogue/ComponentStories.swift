#if DEBUG
import SwiftUI

@MainActor
let componentStories: [Story] = [
    barcodeStory,
    spinnerStory,
    cardRowStory
]

@MainActor
private let barcodeStory = Story(
    id: "barcode-view",
    title: "BarcodeView",
    section: "Components",
    knobs: [
        .text("Code", "5012345678900"),
        .options("Type", BarcodeType.allNames, BarcodeType.ean13.rawValue)
    ],
    gallery: BarcodeType.allCases.map { type in
        (
            name: type.rawValue,
            view: AnyView(
                BarcodeView(barcodeString: SampleCode.valid(for: type), barcodeType: type)
                    .frame(height: 140)
            )
        )
    } + [
        (
            name: "Invalid code",
            view: AnyView(
                BarcodeView(barcodeString: "nope", barcodeType: .ean13)
                    .frame(height: 140)
            )
        )
    ]
) { knobs in
    AnyView(
        BarcodeView(
            barcodeString: knobs.string("Code"),
            barcodeType: .named(knobs.option("Type"))
        )
        .padding()
    )
}

@MainActor
private let spinnerStory = Story(
    id: "spinner",
    title: "Spinner",
    section: "Components",
    knobs: [
        .toggle("Loading", true),
        .number("Grace time", 0, in: 0...2, step: 0.25)
    ],
    gallery: [
        (name: "Loading", view: AnyView(Spinner(isLoading: true))),
        (name: "Idle", view: AnyView(Spinner(isLoading: false))),
        (name: "Loading after 1s grace", view: AnyView(Spinner(isLoading: true, graceTime: 1)))
    ]
) { knobs in
    AnyView(
        Spinner(isLoading: knobs.bool("Loading"), graceTime: knobs.number("Grace time"))
    )
}

@MainActor
private let cardRowStory = Story(
    id: "card-row",
    title: "CardRowView",
    section: "Components",
    knobs: [
        .text("Name", "Tesco Clubcard")
    ],
    gallery: [
        (
            name: "Short name",
            view: AnyView(CardRowView(card: CardSummary.samples[0]) {})
        ),
        (
            name: "Long name",
            view: AnyView(CardRowView(card: .longName) {})
        )
    ]
) { knobs in
    AnyView(
        CardRowView(card: CardSummary(id: "story", name: knobs.string("Name"))) {}
            .padding()
    )
}

#endif
