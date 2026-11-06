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
    /// Counts copies, so each one plays the haptic and shows the tick afresh.
    @State private var copies = 0
    @State private var showsCopied = false

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
            CardFaceView(card: card, accessoryWidth: Self.copyButtonSize) {
                copyCodeButton
            }
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

    private static let copyButtonSize: CGFloat = 44

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
