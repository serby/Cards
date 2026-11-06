import SwiftUI

// The components that write a distance or a radius, in the units chosen in
// Settings (SET-4): their stories have the distance knobs.

@MainActor
let proximityLabelStory = Story(
    id: "proximity-label",
    title: "ProximityLabel",
    section: "Components",
    knobs: ProximityKnobs.knobs(optional: false) + [
        .toggle("Shows place", false),
        .toggle("Highlights here", true),
        .toggle("Wraps", false)
    ],
    gallery: [
        (name: "Here", view: AnyView(ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 0)))),
        (
            name: "Here, with place",
            view: AnyView(ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 0), showsPlace: true))
        ),
        (name: "Nearby", view: AnyView(ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 350)))),
        (
            name: "Nearby, in kilometres",
            view: AnyView(ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 350)).environment(\.distanceUnits, .kilometres))
        ),
        (
            name: "Nearby, in miles",
            view: AnyView(ProximityLabel(CardProximity(placeName: "Boulder Barn", distance: 350)).environment(\.distanceUnits, .miles))
        ),
        (
            name: "Far, with place",
            view: AnyView(ProximityLabel(CardProximity(placeName: "Nordic Nest Wembley", distance: 6_800), showsPlace: true))
        )
    ]
) { knobs in
    AnyView(
        knobs.proximity(optional: false).map { proximity in
            ProximityLabel(
                proximity,
                showsPlace: knobs.bool("Shows place"),
                highlightsHere: knobs.bool("Highlights here"),
                wraps: knobs.bool("Wraps")
            )
                .padding()
                .distances(knobs)
        }
    )
}

@MainActor
let cardLocationRowStory = Story(
    id: "card-location-row",
    title: "CardLocationRow",
    section: "Components",
    knobs: [
        .text("Name", CardLocation.sample.name),
        .number("Radius (m)", CardLocation.sample.radius, in: 50...1_000, step: 25)
    ] + DistanceKnobs.knobs,
    gallery: CardLocation.samples.map { location in
        (name: location.name, view: AnyView(List { CardLocationRow(location) }.frame(height: 90)))
    } + [
        (name: "In yards", view: AnyView(List { CardLocationRow(.sample) }.frame(height: 90).environment(\.distanceUnits, .miles)))
    ]
) { knobs in
    let location = CardLocation(
        name: knobs.string("Name"),
        latitude: CardLocation.sample.latitude,
        longitude: CardLocation.sample.longitude,
        radius: knobs.number("Radius (m)")
    )
    return AnyView(
        List { CardLocationRow(location) }
            .distances(knobs)
    )
}
