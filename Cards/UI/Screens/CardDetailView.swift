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

    @Environment(\.screenBrightness) private var screenBrightness
    @Environment(\.accessibilityAnnouncer) private var announcer
    @State private var originalBrightness: CGFloat?
    @State private var showsLocationPicker = false

    public init(
        card: CardDetail,
        brightnessBoost: Binding<Bool>,
        mapCentre: CLLocationCoordinate2D? = nil,
        actions: CardDetailActions = CardDetailActions()
    ) {
        self.card = card
        _brightnessBoost = brightnessBoost
        self.mapCentre = mapCentre
        self.actions = actions
    }

    public var body: some View {
        VStack {
            VStack(spacing: CardGeometry.inset) {
                VStack(spacing: 6) {
                    Text(card.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(CardPanel.ink)
                        .accessibilityIdentifier("cardNameText")
                        .accessibilityLabel("Card name: \(card.name)")
                        .accessibilityAddTraits(.isHeader)

                    if let proximity = card.proximity {
                        ProximityLabel(proximity, showsPlace: true)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(CardPanel.secondaryInk)
                            .accessibilityIdentifier("cardProximityText")
                    }
                }
                .cardPanel()

                BarcodeView(barcodeString: card.code, barcodeType: card.barcodeType)
                    .accessibilityLabel("Barcode for \(card.name)")

                VStack(spacing: 4) {
                    Text(card.code)
                        .font(.title3.monospaced().weight(.semibold))
                        .foregroundStyle(CardPanel.ink)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("cardCodeText")
                        .accessibilityLabel(Text("Card code: ") + Text(card.code).speechSpellsOutCharacters())
                        .accessibilityAddTraits(.isStaticText)

                    Text("\(card.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(CardPanel.secondaryInk)
                        .accessibilityIdentifier("cardTimestampText")
                        .accessibilityLabel("Created on \(card.timestamp, format: Date.FormatStyle(date: .long, time: .shortened))")
                        .accessibilityAddTraits(.isStaticText)
                }
                .cardPanel()
            }
            .padding(CardGeometry.inset)
            .frame(maxWidth: .infinity)
            .background(card.color.cardFill, in: .rect(cornerRadius: CardGeometry.cornerRadius))
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)

            // Pointless where the card already is, so it goes once you are inside one of its places.
            if card.proximity?.isHere != true {
                addCurrentLocationButton
            }
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showsLocationPicker) {
            LocationPickerView(
                centre: mapCentre,
                findPlace: actions.findPlace,
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

private extension View {
    /// A white panel for text on the card face, its corners nested inside the card's.
    func cardPanel() -> some View {
        padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(CardPanel.fill, in: .rect(cornerRadius: CardGeometry.panelCornerRadius))
    }
}
