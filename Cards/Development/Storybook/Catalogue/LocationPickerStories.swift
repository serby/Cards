import MapKit
import SwiftUI

/// The location picker brings its own NavigationStack, as a sheet does.
@MainActor
let locationPickerStory = Story(
    id: "location-picker",
    title: "LocationPickerView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .options("Start at", PickerStart.allCases.map(\.rawValue), PickerStart.boulderBarn.rawValue),
        .options("Search", SearchBehaviour.allCases.map(\.rawValue), SearchBehaviour.finds.rawValue),
        .text("Search text", ""),
        .toggle("Editing Boulder Barn", false)
    ] + DistanceKnobs.knobs,
    gallery: [
        (name: "Boulder Barn", view: AnyView(picker(searching: .sample))),
        (name: "Suggestions", view: AnyView(picker(searching: .sample, for: "Joe"))),
        (name: "No place found", view: AnyView(picker(searching: .noMatches, for: "Corner Grocer"))),
        (name: "Searching", view: AnyView(picker(searching: .searching, for: "Local Roast"))),
        (name: "Offline", view: AnyView(picker(searching: .failing(.offline), for: "Local Roast"))),
        (name: "Search not working", view: AnyView(picker(searching: .failing(.unavailable), for: "Local Roast"))),
        (
            name: "Editing Nordic Nest Wembley",
            view: AnyView(LocationPickerView(editing: CardLocation.samples[2], search: .sample, onSave: { _ in }))
        )
    ]
) { knobs in
    let start = PickerStart(rawValue: knobs.option("Start at")) ?? .boulderBarn
    let behaviour = SearchBehaviour(rawValue: knobs.option("Search")) ?? .finds
    let text = knobs.string("Search text")
    let editing = knobs.bool("Editing Boulder Barn")
    return AnyView(
        Group {
            if editing {
                // Editing opens on the place with an empty search, so "Start at" and the text do not apply.
                LocationPickerView(editing: .sample, search: behaviour.search, onSave: { _ in })
            } else {
                LocationPickerView(initialPosition: start.position, search: behaviour.search, query: text, onAdd: { _ in })
            }
        }
        // The start position and search text are read once, so a new choice needs a fresh picker.
        .id("\(start)-\(behaviour)-\(text)-\(editing)")
        .distances(knobs)
    )
}

@MainActor
private func picker(searching search: PlaceSearch, for query: String = "") -> LocationPickerView {
    LocationPickerView(initialPosition: .region(CardLocation.previewRegion), search: search, query: query, onAdd: { _ in })
}

private enum SearchBehaviour: String, CaseIterable {
    case finds = "Finds places"
    case findsNothing = "Finds nothing"
    case searching = "Still searching"
    case offline = "Offline"
    case notWorking = "Not working"

    var search: PlaceSearch {
        switch self {
        case .finds:
            .sample
        case .findsNothing:
            .noMatches
        case .searching:
            .searching
        case .offline:
            .failing(.offline)
        case .notWorking:
            .failing(.unavailable)
        }
    }
}

private enum PickerStart: String, CaseIterable {
    case boulderBarn = "Boulder Barn"
    case centralLondon = "Central London"
    case userLocation = "Your location"

    var position: MapCameraPosition {
        switch self {
        case .boulderBarn:
            .region(CardLocation.previewRegion)
        case .centralLondon:
            .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                    latitudinalMeters: 3_000,
                    longitudinalMeters: 3_000
                )
            )
        case .userLocation:
            .userLocation(fallback: .automatic)
        }
    }
}
