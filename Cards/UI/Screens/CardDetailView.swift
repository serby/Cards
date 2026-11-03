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
        VStack {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text(card.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(card.color.primaryInk)
                        .accessibilityIdentifier("cardNameText")
                        .accessibilityLabel(
                            Text(
                                "Card name: \(card.name)",
                                comment: "VoiceOver label for the name at the top of a card's screen. The argument is a name, such as Tesco."
                            )
                        )
                        .accessibilityAddTraits(.isHeader)

                    if let proximity = card.proximity {
                        ProximityLabel(proximity, showsPlace: true)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(card.color.secondaryInk)
                            .accessibilityIdentifier("cardProximityText")
                    }
                }

                BarcodeView(barcodeString: card.code, barcodeType: card.barcodeType)
                    .accessibilityLabel(
                        Text(
                            "Barcode for \(card.name)",
                            comment: "VoiceOver label for the barcode image on a card's screen. The argument is the card's name."
                        )
                    )

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
                        .foregroundStyle(card.color.secondaryInk)
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
            .background(card.color.cardFill, in: .rect(cornerRadius: 24))
            .keepsColoursWhenInverted()
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardDetailView")
        .task {
            guard brightnessBoost else { return }
            await boost()
            announcer.announce(
                String(
                    localized: "Screen brightness increased for better barcode visibility",
                    comment: "VoiceOver announcement when a card's screen opens with Brightness Boost on and turns the screen up."
                )
            )
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
                .accessibilityHint(
                    Text(
                        "Toggles screen brightness to maximum for easier barcode scanning",
                        comment: "VoiceOver hint for the Brightness Boost button on a card's screen."
                    )
                )
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: actions.editCard) {
                    Text("Edit", comment: "Toolbar button on a card's screen that opens the card for editing. A verb.")
                }
                .accessibilityIdentifier("editCardButton")
                .accessibilityLabel(Text("Edit card", comment: "VoiceOver label for the Edit button on a card's screen."))
                .accessibilityHint(Text("Tap to edit this card's details", comment: "VoiceOver hint for the Edit button on a card's screen."))
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
                String(localized: "Brightness boost on", comment: "VoiceOver announcement after the sun button turns Brightness Boost on.")
            )
        } else {
            await screenBrightness.fade(to: originalBrightness ?? 0.5, duration: 0.2)
            announcer.announce(
                String(localized: "Brightness boost off", comment: "VoiceOver announcement after the sun button turns Brightness Boost off.")
            )
        }
    }
}
