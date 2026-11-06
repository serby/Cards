import SwiftUI

// The parts of the location picker's map and panel.

/// The pin and its ring, over a plain fill where the map would be.
@MainActor
let mapPinRingStory = Story(
    id: "map-pin-ring",
    title: "MapPinRing",
    section: "Components",
    knobs: [
        .toggle("Map has reported its scale", true),
        .number("Ring diameter (pt)", 180, in: 20...400, step: 10)
    ],
    gallery: [
        (name: "With ring", view: AnyView(onMap(MapPinRing(diameter: 180)))),
        (name: "Before the map reports", view: AnyView(onMap(MapPinRing(diameter: nil))))
    ]
) { knobs in
    AnyView(onMap(MapPinRing(diameter: knobs.bool("Map has reported its scale") ? knobs.number("Ring diameter (pt)") : nil)))
}

@MainActor
private func onMap(_ pin: MapPinRing) -> some View {
    pin
        .frame(height: 320)
        .background(Color(UIColor.secondarySystemBackground))
}

@MainActor
let radiusSliderStory = Story(
    id: "radius-slider",
    title: "RadiusSlider",
    section: "Components",
    knobs: [
        .number("Radius (m)", CardLocation.defaultRadius, in: CardLocation.radiusRange, step: 25)
    ],
    gallery: [
        slider(at: CardLocation.radiusRange.lowerBound),
        slider(at: CardLocation.defaultRadius),
        slider(at: CardLocation.radiusRange.upperBound)
    ]
) { knobs in
    AnyView(RadiusSlider(radius: knobs.numberBinding("Radius (m)")).padding())
}

@MainActor
private func slider(at radius: Double) -> (name: String, view: AnyView) {
    (name: radius.radiusText, view: AnyView(Stateful(radius) { RadiusSlider(radius: $0) }.padding()))
}

/// The list under the location picker's search field, on a panel like the picker's.
@MainActor
let placeSearchResultsStory = Story(
    id: "place-search-results",
    title: "PlaceSearchResults",
    section: "Components",
    knobs: [
        .options("Status", ResultsKind.allCases.map(\.rawValue), ResultsKind.suggestions.rawValue),
        .text("Search text", "Joe")
    ],
    gallery: ResultsKind.allCases.map { kind in
        (name: kind.rawValue, view: AnyView(panel(kind.status(for: kind == .notFound ? "Corner Grocer" : "Local Roast"))))
    }
) { knobs in
    let kind = ResultsKind(rawValue: knobs.option("Status")) ?? .suggestions
    return AnyView(panel(kind.status(for: knobs.string("Search text"))))
}

@MainActor
private func panel(_ status: PlaceSearchStatus) -> some View {
    PlaceSearchResults(status: status)
        .padding(18)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .padding()
}

private enum ResultsKind: String, CaseIterable {
    case suggestions = "Suggestions"
    case searching = "Searching"
    case notFound = "No place found"
    case offline = "Offline"
    case notWorking = "Not working"

    func status(for text: String) -> PlaceSearchStatus {
        switch self {
        case .suggestions:
            .answer(PlaceSuggestion.samples(for: text), to: text)
        case .searching:
            .searching
        case .notFound:
            .notFound(text)
        case .offline:
            .failed(.offline)
        case .notWorking:
            .failed(.unavailable)
        }
    }
}
