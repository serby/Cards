import SwiftUI

/// The "Add Card?" sheet brings its own NavigationStack, as a sheet does.
@MainActor
let sharedCardStory = Story(
    id: "shared-card",
    title: "SharedCardView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .options("State", SharedCardKind.allCases.map(\.rawValue), SharedCardKind.new.rawValue),
        .text("Name", CardDetail.sample.name),
        .text("Code", CardDetail.sample.code),
        .options("Type", BarcodeType.allNames, BarcodeType.ean13.rawValue),
        .options("Colour", CardColor.allNames, CardDetail.sample.color.rawValue),
        SymbolKnob.knob(CardDetail.sample.symbol),
        .number("Locations", 1, in: 0...Double(CardLocation.samples.count), step: 1)
    ],
    gallery: SharedCardKind.allCases.map { kind in
        (name: kind.rawValue, view: AnyView(SharedCardView(state: kind.state(sharedFace, places: [.sample]))))
    }
) { knobs in
    let face = CardDetail(
        id: "story",
        name: knobs.string("Name"),
        code: knobs.string("Code"),
        barcodeType: .named(knobs.option("Type")),
        timestamp: .now,
        color: .named(knobs.option("Colour")),
        symbol: knobs.symbol
    )
    let kind = SharedCardKind(rawValue: knobs.option("State")) ?? .new
    let places = Array(CardLocation.samples.prefix(knobs.integer("Locations")))
    return AnyView(SharedCardView(state: kind.state(face, places: places)))
}

/// The sample card as a link brings it: no distance, because the places are someone else's.
@MainActor
private let sharedFace = CardDetail(
    id: CardDetail.sample.id,
    name: CardDetail.sample.name,
    code: CardDetail.sample.code,
    barcodeType: CardDetail.sample.barcodeType,
    timestamp: CardDetail.sample.timestamp,
    color: CardDetail.sample.color,
    symbol: CardDetail.sample.symbol
)

/// The sheet's three states, for the State knob.
private enum SharedCardKind: String, CaseIterable {
    case new = "New card"
    case alreadyAdded = "Already added"
    case unreadable = "No card in the link"

    func state(_ face: CardDetail, places: [CardLocation]) -> SharedCardState {
        switch self {
        case .new:
            .new(face, places: places)
        case .alreadyAdded:
            .alreadyAdded(face, places: places)
        case .unreadable:
            .unreadable
        }
    }
}
