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
        .toggle("Postcode found", true),
        .toggle("Editing Boulder Barn", false)
    ],
    gallery: [
        (
            name: "Boulder Barn",
            view: AnyView(
                LocationPickerView(
                    initialPosition: .region(CardLocation.previewRegion),
                    findPlace: { _ in nil },
                    onAdd: { _ in }
                )
            )
        ),
        (
            name: "Editing Nordic Nest Wembley",
            view: AnyView(
                LocationPickerView(editing: CardLocation.samples[2], findPlace: { _ in nil }, onSave: { _ in })
            )
        )
    ]
) { knobs in
    let start = PickerStart(rawValue: knobs.option("Start at")) ?? .boulderBarn
    let found = knobs.bool("Postcode found")
    let editing = knobs.bool("Editing Boulder Barn")
    let findPlace: (String) async -> PlaceMatch? = { query in
        found ? PlaceMatch(name: query.uppercased(), latitude: 51.5203, longitude: -0.2094) : nil
    }
    return AnyView(
        Group {
            if editing {
                // Editing opens on the place, so "Start at" does not apply.
                LocationPickerView(editing: .sample, findPlace: findPlace, onSave: { _ in })
            } else {
                LocationPickerView(initialPosition: start.position, findPlace: findPlace, onAdd: { _ in })
            }
        }
        // The start position is read once, so a new choice needs a fresh picker.
        .id("\(start)-\(editing)")
    )
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
