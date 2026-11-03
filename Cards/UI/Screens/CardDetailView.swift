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
                        .accessibilityLabel("Card name: \(card.name)")
                        .accessibilityAddTraits(.isHeader)

                    if let proximity = card.proximity {
                        ProximityLabel(proximity, showsPlace: true)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(card.color.secondaryInk)
                            .accessibilityIdentifier("cardProximityText")
                    }
                }

                BarcodeView(barcodeString: card.code, barcodeType: card.barcodeType)
                    .accessibilityLabel("Barcode for \(card.name)")

                VStack(spacing: 4) {
                    Text(card.code)
                        .font(.title3.monospaced().weight(.semibold))
                        .foregroundStyle(card.color.primaryInk)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("cardCodeText")
                        .accessibilityLabel(Text("Card code: ") + Text(card.code).speechSpellsOutCharacters())
                        .accessibilityAddTraits(.isStaticText)

                    Text("\(card.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(card.color.secondaryInk)
                        .accessibilityIdentifier("cardTimestampText")
                        .accessibilityLabel("Created on \(card.timestamp, format: Date.FormatStyle(date: .long, time: .shortened))")
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(card.color.cardFill, in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            Spacer()
        }
        .padding()
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
