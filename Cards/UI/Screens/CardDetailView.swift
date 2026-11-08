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
    /// VoiceOver starts on the card's name, which also confirms a save.
    @AccessibilityFocusState private var nameFocused: Bool
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
        // Scrolls once the card is taller than the screen, with several places (PLACE-9), long notes (CARD-14) or
        // at the largest text sizes, so the text never squeezes the barcode below a size a scanner reads.
        ScrollView {
            VStack {
                CardFaceView(card: card, accessoryWidth: Self.copyButtonSize, nameFocus: $nameFocused, linksNearestPlace: true) {
                    copyCodeButton
                } footer: {
                    if card.places.isListed {
                        PlacesPanel(places: card.places)
                    }
                    if let notes = card.notes {
                        NotesPanel(notes: notes)
                    }
                }
                // Flattened, so only the card's outline casts it: every line of text cast its own, a grey
                // haze on the panels that the audit measured below AA at the largest text sizes.
                .compositingGroup()
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
        // No announcement here: it would cut across VoiceOver reading the new
        // screen every time it opens. The button says whether the boost is on.
        .task {
            guard brightnessBoost else { return }
            await boost()
        }
        .task {
            // After the push settles, or VoiceOver moves focus to the bar.
            try? await Task.sleep(for: .seconds(0.5))
            nameFocused = true
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
                .accessibilityLabel(
                    Text(
                        "Brightness Boost",
                        comment: "VoiceOver label for the sun button on a card's screen, which turns the screen up so scanners can read the barcode."
                    )
                )
                // The state is otherwise only the icon's fill and tint.
                .accessibilityAddTraits(.isToggle)
                .accessibilityValue(
                    brightnessBoost
                        ? Text("On", comment: "VoiceOver value of the Brightness Boost button on a card's screen when the boost is on.")
                        : Text("Off", comment: "VoiceOver value of the Brightness Boost button on a card's screen when the boost is off.")
                )
                .accessibilityHint(
                    Text(
                        "Turns full brightness on or off, so the barcode scans easily",
                        comment: "VoiceOver hint for the Brightness Boost button on a card's screen. It works both ways: on when off, off when on."
                    )
                )
                // The button shows only a sun, so Voice Control users guess at its
                // name; let the shorter one work too.
                .accessibilityInputLabels([
                    Text(
                        "Brightness Boost",
                        comment: "VoiceOver label for the sun button on a card's screen, which turns the screen up so scanners can read the barcode."
                    ),
                    Text("Brightness", comment: "A name Voice Control users can say for the Brightness Boost button on a card's screen.")
                ])
            }

            // Labelled by its visible text, so "Tap Edit" works in Voice Control.
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: actions.editCard) {
                    Text("Edit", comment: "Toolbar button on a card's screen that opens the card for editing. A verb.")
                }
                .keyboardShortcut("e")
                .accessibilityIdentifier("editCardButton")
                .accessibilityHint(Text("Opens the card for editing", comment: "VoiceOver hint for the Edit button on a card's screen."))
            }
        }
    }

    private static let copyButtonSize: CGFloat = 44

    /// Sends the card as a link someone can add (SHARE-1), or as a picture (SHARE-2).
    private func shareMenu(_ share: CardShare) -> some View {
        Menu {
            ShareLink(item: share.link, subject: Text(card.name), preview: SharePreview(card.name)) {
                Label(
                    LocalizedStringResource("Share Link", comment: "Share menu item on a card's screen: sends a link that adds the card."),
                    systemImage: "link"
                )
            }
            .accessibilityIdentifier("shareLinkButton")

            ShareLink(item: share.image, preview: SharePreview(card.name, image: share.image)) {
                Label(
                    LocalizedStringResource("Share Image", comment: "Share menu item on a card's screen: sends a picture of the card."),
                    systemImage: "photo"
                )
            }
            .accessibilityIdentifier("shareImageButton")
        } label: {
            Image(systemName: "square.and.arrow.up")
                .accessibilityHidden(true)
        }
        .accessibilityIdentifier("shareCardButton")
        .accessibilityLabel(
            Text("Share card", comment: "VoiceOver label for the share button, the share icon, in the toolbar of a card's screen.")
        )
        .accessibilityHint(
            Text("Shares this card as a link to add it, or as an image", comment: "VoiceOver hint for the share button on a card's screen.")
        )
    }

    /// Copies the number, for typing it into a website or another app. The icon
    /// turns into a tick for a moment to show it worked.
    private var copyCodeButton: some View {
        Button {
            actions.copyCode()
            copies += 1
            announcer.announce(
                String(localized: "Card code copied", comment: "VoiceOver announcement after the copy button on a card's screen copies the code.")
            )
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
        .accessibilityLabel(
            showsCopied
                ? Text("Copied", comment: "VoiceOver label for the copy button beside the code on a card's screen, just after a copy.")
                : Text("Copy card code", comment: "VoiceOver label for the copy button, an icon, beside the code on a card's screen.")
        )
    }

    /// A quiet way to remember this place for the card, without opening the editor.
    private var addCurrentLocationButton: some View {
        Button {
            showsLocationPicker = true
        } label: {
            Label(
                LocalizedStringResource("Add current location", comment: "Button below a card on its screen: opens a map to save a place for it."),
                systemImage: "location"
            )
            .font(.footnote.weight(.medium))
            // Quiet, but 44 pt tall like any button.
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        // Supporting text (the system grey is 3.4:1 on white), below the card's 24 pt shadow, whose grey failed contrast.
        .foregroundStyle(Color.secondaryText)
        .padding(.top, 24)
        .accessibilityIdentifier("addCurrentLocationButton")
        .accessibilityHint(
            Text(
                "Opens a map to save where you are as one of this card's places",
                comment: "VoiceOver hint for the Add current location button below the card on a card's screen."
            )
        )
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
            announcer.announce(
                String(localized: "Brightness Boost on", comment: "VoiceOver announcement after the sun button turns Brightness Boost on.")
            )
        } else {
            await screenBrightness.fade(to: originalBrightness ?? 0.5, duration: 0.2)
            announcer.announce(
                String(localized: "Brightness Boost off", comment: "VoiceOver announcement after the sun button turns Brightness Boost off.")
            )
        }
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

#Preview("Notes") {
    @Previewable @State var boost = true
    NavigationStack {
        CardDetailView(card: .withNotes, brightnessBoost: $boost)
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
