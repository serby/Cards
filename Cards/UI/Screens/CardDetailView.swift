import SwiftUI

/// The card detail screen. Brightness and VoiceOver announcements go through
/// the environment so this renders safely outside the app.
public struct CardDetailView: View {
    private let card: CardDetail
    @Binding private var brightnessBoost: Bool
    private let actions: CardDetailActions

    @Environment(\.screenBrightness) private var screenBrightness
    @Environment(\.accessibilityAnnouncer) private var announcer
    @State private var originalBrightness: CGFloat?
    /// VoiceOver starts on the card's name, which also confirms a save.
    @AccessibilityFocusState private var nameFocused: Bool
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    /// The distance and date: a lighter ink, or with Increase Contrast the
    /// full ink of the name and code.
    private var supportingInk: Color {
        colorSchemeContrast == .increased ? card.color.primaryInk : card.color.secondaryInk
    }

    public init(
        card: CardDetail,
        brightnessBoost: Binding<Bool>,
        actions: CardDetailActions = CardDetailActions()
    ) {
        self.card = card
        _brightnessBoost = brightnessBoost
        self.actions = actions
    }

    public var body: some View {
        // Scrolls once the card is taller than the screen, as at the largest
        // text sizes, so the text can never squeeze the barcode below a size a
        // scanner reads, and nothing is cut off.
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text(card.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(card.color.primaryInk)
                        .accessibilityIdentifier("cardNameText")
                        // The name alone, so the headings rotor lists cards by name.
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($nameFocused)

                    if let proximity = card.proximity {
                        ProximityLabel(proximity, showsPlace: true)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(supportingInk)
                            .accessibilityIdentifier("cardProximityText")
                    }
                }

                BarcodeView(barcodeString: card.code, barcodeType: card.barcodeType)

                VStack(spacing: 4) {
                    Text(card.code)
                        .font(.title3.monospaced().weight(.semibold))
                        .foregroundStyle(card.color.primaryInk)
                        .readsLeftToRight()
                        .textSelection(.enabled)
                        .accessibilityIdentifier("cardCodeText")
                        .accessibilityLabel(
                            Text(
                                "Card code: \(Text(card.code).speechSpellsOutCharacters())",
                                comment: "VoiceOver label for the code under the barcode, which VoiceOver spells out character by character."
                            )
                        )
                        .accessibilityAddTraits(.isStaticText)

                    Text(card.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(supportingInk)
                        .accessibilityIdentifier("cardTimestampText")
                        .accessibilityLabel(
                            Text(
                                "Created on \(card.timestamp, format: Date.FormatStyle(date: .long, time: .shortened))",
                                comment: "VoiceOver label for when the card was added. The argument is a date and time: 14 November 2023 at 22:13."
                            )
                        )
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            // The shadow belongs to the card's shape alone. On the whole card it
            // fell on every glyph too, haloing the text and lowering its contrast.
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(card.color.cardFill)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            }
            // With Increase Contrast the card gets an edge: the default grey card
            // is barely lighter than the screen behind it.
            .overlay {
                if colorSchemeContrast == .increased {
                    RoundedRectangle(cornerRadius: 24).strokeBorder(Color.primaryText, lineWidth: 1)
                }
            }
            .keepsColoursWhenInverted()
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
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
                        "Toggles screen brightness to maximum for easier barcode scanning",
                        comment: "VoiceOver hint for the Brightness Boost button on a card's screen."
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
