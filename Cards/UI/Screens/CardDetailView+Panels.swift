import SwiftUI

// The panels the card screen puts at the foot of the card face, beside
// CardDetailView.swift so each file stays readable. Internal rather than
// private only so the two files share them.

/// A card's places on a white panel at the foot of its face (PLACE-9): each
/// name with its distance, nearest first, or in the card's order while where
/// you are is unknown. A place opens in the maps app chosen in Settings (SET-5).
struct PlacesPanel: View {
    let places: CardPlaces

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    @Environment(\.distanceFormat) private var distanceFormat
    @Environment(\.mapsApp) private var mapsApp

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CardPanel.secondaryInk)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("cardPlacesHeading")

            ForEach(Array(places.listed.enumerated()), id: \.element.id) { index, place in
                if index > 0 {
                    separator
                }
                row(place)
            }

            if places.unlisted > 0 {
                Text(
                    "\(places.unlisted) more places",
                    comment: "Below the places listed on a card's screen: how many more the card has. The argument is one or more."
                )
                .font(.footnote)
                .foregroundStyle(CardPanel.secondaryInk)
                .padding(.top, 4)
                .accessibilityIdentifier("cardMorePlacesText")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardPlacesList")
    }

    /// "Nearest places" once there are distances to order them by.
    private var heading: Text {
        places.hasDistances
            ? Text("Nearest places", comment: "Heading of the list of a card's places on its screen, nearest to the user first.")
            : Text("Places", comment: "Heading of the list of a card's places on its screen, when the app does not know where the user is. A noun.")
    }

    /// One place, tall enough to tap, read as its name and distance (A11Y-1).
    @ViewBuilder
    private func row(_ place: NearbyPlace) -> some View {
        if let url = place.location.mapsURL(in: mapsApp) {
            Link(destination: url) {
                rowContent(place)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spoken(place))
            .accessibilityHint(Text.opensPlace(in: mapsApp))
            .accessibilityIdentifier("cardPlaceRow")
        } else {
            rowContent(place)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken(place))
                .accessibilityIdentifier("cardPlaceRow")
        }
    }

    /// The name, wrapping as far as it needs, with the distance beside it, or
    /// below it at the accessibility text sizes.
    private func rowContent(_ place: NearbyPlace) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            Text(place.location.name)
                .foregroundStyle(CardPanel.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let proximity = place.proximity {
                ProximityLabel(proximity)
                    .foregroundStyle(CardPanel.secondaryInk)
                    .fixedSize()
            }
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .contentShape(.rect)
    }

    /// The distance as VoiceOver reads it, naming the place, or just the place.
    private func spoken(_ place: NearbyPlace) -> String {
        place.proximity?.spokenDescription(in: distanceFormat) ?? place.location.name
    }

    /// A hairline in the panel's ink, which stays dark on the white panel in dark mode.
    private var separator: some View {
        Rectangle()
            .fill(CardPanel.ink.opacity(0.12))
            .frame(height: 1 / displayScale)
            .accessibilityHidden(true)
    }
}

/// A card's notes on a white panel at the foot of its face, below its places
/// (CARD-14), so the barcode stays first. They keep their line breaks, wrap at
/// every text size and can be selected, to copy a line of them.
struct NotesPanel: View {
    let notes: String

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notes", comment: "Heading of a card's notes, on the card's screen and in the card form. A noun.")
                .font(.footnote.weight(.semibold))
                // With Increase Contrast, the full ink of the notes.
                .foregroundStyle(colorSchemeContrast == .increased ? CardPanel.ink : CardPanel.secondaryInk)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("cardNotesHeading")

            // The card holder's own words, shown as typed and never looked up.
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(CardPanel.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .accessibilityIdentifier("cardNotesText")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardNotesPanel")
    }
}
