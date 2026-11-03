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
            VStack {
                Text(card.name)
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
                    .accessibilityIdentifier("cardNameText")
                    .accessibilityLabel("Card name: \(card.name)")
                    .accessibilityAddTraits(.isHeader)
                
                BarcodeView(barcodeString: card.code, barcodeType: card.barcodeType)
                    .accessibilityLabel("Barcode for \(card.name)")
                Text(card.code)
                    .font(.headline)
                    .accessibilityIdentifier("cardCodeText")
                    .accessibilityLabel("Card code: \(card.code)")
                    .accessibilityAddTraits(.isStaticText)
                
                Text("\(card.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("cardTimestampText")
                    .accessibilityLabel("Created on \(card.timestamp, format: Date.FormatStyle(date: .long, time: .shortened))")
                    .accessibilityAddTraits(.isStaticText)
            }
            .padding()
            .background(.gray.opacity(0.25), in: .rect(cornerRadius: 24))
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
                        .foregroundStyle(brightnessBoost ? Color.accentColor : .primary)
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

#Preview {
    @Previewable @State var boost = true
    NavigationStack {
        CardDetailView(card: .sample, brightnessBoost: $boost)
    }
    .environment(\.screenBrightness, .simulated(BrightnessBox()))
    .environment(\.accessibilityAnnouncer, .silent)
}


#Preview {
    @Previewable @State var boost = true
    NavigationStack {
        CardDetailView(card: .invalidCode, brightnessBoost: $boost)
    }
    .environment(\.screenBrightness, .simulated(BrightnessBox()))
    .environment(\.accessibilityAnnouncer, .silent)
}
