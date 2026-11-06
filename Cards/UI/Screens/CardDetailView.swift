import CoreLocation
import SwiftUI

/// The card detail screen. Brightness and VoiceOver announcements go through
/// the environment so this renders safely outside the app.
public struct CardDetailView: View {
    private let card: CardDetail
    @Binding private var brightnessBoost: Bool
    private let actions: CardDetailActions
    /// Where the location picker opens: the user's last known location, if any.
    private let mapCentre: CLLocationCoordinate2D?
    /// What the share menu sends; no share button without it.
    private let share: CardShare?

    @Environment(\.screenBrightness) private var screenBrightness
    @Environment(\.accessibilityAnnouncer) private var announcer
    @State private var originalBrightness: CGFloat?
    @State private var showsLocationPicker = false
    /// Counts copies, so each one plays the haptic and shows the tick afresh.
    @State private var copies = 0
    @State private var showsCopied = false

    public init(
        card: CardDetail,
        brightnessBoost: Binding<Bool>,
        mapCentre: CLLocationCoordinate2D? = nil,
        share: CardShare? = nil,
        actions: CardDetailActions = CardDetailActions()
    ) {
        self.card = card
        _brightnessBoost = brightnessBoost
        self.mapCentre = mapCentre
        self.share = share
        self.actions = actions
    }

    public var body: some View {
        // Scrolls once a card's places make it taller than the screen (PLACE-9).
        ScrollView {
            VStack {
                CardFaceView(card: card, accessoryWidth: Self.copyButtonSize) {
                    copyCodeButton
                } footer: {
                    if card.places.isListed {
                        PlacesPanel(places: card.places)
                    }
                }
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)

                // Pointless where the card already is, so it goes once you are inside one of its places.
                if card.proximity?.isHere != true {
                    addCurrentLocationButton
                }
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .sheet(isPresented: $showsLocationPicker) {
            LocationPickerView(
                centre: mapCentre,
                search: actions.placeSearch,
                onAppear: actions.requestLocationAccess,
                onAdd: actions.addLocation
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardDetailView")
        .task {
            guard brightnessBoost else { return }
            await boost()
            announcer.announce("Screen brightness increased for better barcode visibility")
        }
        .onDisappear {
            guard let originalBrightness else { return }
            let brightness = screenBrightness
            Task { await brightness.fade(to: originalBrightness, duration: 0.2) }
        }
        .toolbar {
            // Share first, so brightness and Edit keep the places they had at the trailing edge.
            if let share {
                ToolbarItem(placement: .navigationBarTrailing) {
                    shareMenu(share)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    brightnessBoost.toggle()
                    Task { await applyToggle() }
                } label: {
                    Image(systemName: brightnessBoost ? "sun.max.fill" : "sun.max")
                        .foregroundStyle(brightnessBoost ? Color.accent : .primary)
                }
                .accessibilityIdentifier("brightnessToggleButton")
                .accessibilityLabel("Brightness Boost")
                .accessibilityHint("Toggles screen brightness to maximum for easier barcode scanning")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit", action: actions.editCard)
                    .accessibilityIdentifier("editCardButton")
                    .accessibilityLabel("Edit card")
                    .accessibilityHint("Tap to edit this card's details")
            }
        }
    }

    private static let copyButtonSize: CGFloat = 44

    /// Sends the card as a link someone can add (SHARE-1), or as a picture (SHARE-2).
    private func shareMenu(_ share: CardShare) -> some View {
        Menu {
            ShareLink(item: share.link, subject: Text(card.name), preview: SharePreview(card.name)) {
                Label("Share Link", systemImage: "link")
            }
            .accessibilityIdentifier("shareLinkButton")

            ShareLink(item: share.image, preview: SharePreview(card.name, image: share.image)) {
                Label("Share Image", systemImage: "photo")
            }
            .accessibilityIdentifier("shareImageButton")
        } label: {
            Image(systemName: "square.and.arrow.up")
                .accessibilityHidden(true)
        }
        .accessibilityIdentifier("shareCardButton")
        .accessibilityLabel("Share card")
        .accessibilityHint("Shares this card as a link to add it, or as an image")
    }

    /// Copies the number, for typing it into a website or another app. The icon
    /// turns into a tick for a moment to show it worked.
    private var copyCodeButton: some View {
        Button {
            actions.copyCode()
            copies += 1
            announcer.announce("Card code copied")
        } label: {
            Image(systemName: showsCopied ? "checkmark" : "doc.on.doc")
                .font(.body.weight(.semibold))
                .foregroundStyle(CardPanel.secondaryInk)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Self.copyButtonSize, height: Self.copyButtonSize)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: copies)
        .task(id: copies) {
            guard copies > 0 else { return }
            showsCopied = true
            // A tap while the tick shows starts the moment again.
            guard (try? await Task.sleep(for: .seconds(1.5))) != nil else { return }
            showsCopied = false
        }
        .accessibilityIdentifier("copyCodeButton")
        .accessibilityLabel(showsCopied ? "Copied" : "Copy card code")
    }

    /// A quiet way to remember this place for the card, without opening the editor.
    private var addCurrentLocationButton: some View {
        Button {
            showsLocationPicker = true
        } label: {
            Label("Add current location", systemImage: "location")
                .font(.footnote.weight(.medium))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .padding(.top, 12)
        .accessibilityIdentifier("addCurrentLocationButton")
        .accessibilityHint("Opens a map to save where you are as one of this card's places")
    }

    private func boost() async {
        if originalBrightness == nil {
            originalBrightness = screenBrightness.read()
        }
        await screenBrightness.fade(to: 1.0, duration: 0.5)
    }

    private func applyToggle() async {
        if brightnessBoost {
            await boost()
            announcer.announce("Brightness boost on")
        } else {
            await screenBrightness.fade(to: originalBrightness ?? 0.5, duration: 0.2)
            announcer.announce("Brightness boost off")
        }
    }
}

/// A card's places on a white panel at the foot of its face (PLACE-9): each
/// name with its distance, nearest first, or in the card's order while where
/// you are is unknown. A place opens in Maps.
private struct PlacesPanel: View {
    let places: CardPlaces

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    @Environment(\.distanceFormat) private var distanceFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(places.hasDistances ? "Nearest places" : "Places")
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
                Text(places.unlisted == 1 ? "1 more place" : "\(places.unlisted) more places")
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

    /// One place, tall enough to tap, read as its name and distance (A11Y-1).
    @ViewBuilder
    private func row(_ place: NearbyPlace) -> some View {
        if let url = place.location.mapsURL {
            Link(destination: url) {
                rowContent(place)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spoken(place))
            .accessibilityHint("Opens this place in Maps")
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

#if DEBUG
#Preview("Sample") {
    @Previewable @State var boost = true
    NavigationStack {
        CardDetailView(card: .sample, brightnessBoost: $boost)
    }
    .environment(\.screenBrightness, .simulated(BrightnessBox()))
    .environment(\.accessibilityAnnouncer, .silent)
}

#Preview("Seven places") {
    @Previewable @State var boost = true
    NavigationStack {
        CardDetailView(card: .sevenPlaces, brightnessBoost: $boost)
    }
    .environment(\.screenBrightness, .simulated(BrightnessBox()))
    .environment(\.accessibilityAnnouncer, .silent)
}

#Preview("Places, no location") {
    @Previewable @State var boost = true
    NavigationStack {
        CardDetailView(card: .placesWithoutLocation, brightnessBoost: $boost)
    }
    .environment(\.screenBrightness, .simulated(BrightnessBox()))
    .environment(\.accessibilityAnnouncer, .silent)
}
#endif
