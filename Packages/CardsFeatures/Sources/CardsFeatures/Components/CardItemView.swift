import CardsCore
import CardsUI
import SwiftData
import SwiftUI
import UIKit

public struct CardItemView: View {
    @AppStorage("brightnessBoost") private var brightnessBoost = true
    @State private var originalBrightness: CGFloat = UIScreen.current?.brightness ?? 0.5
    @State private var item: CardItem
    let navigationManager: NavigationManager

    public init(item: CardItem, navigationManager: NavigationManager) {
        _item = State(initialValue: item)
        self.navigationManager = navigationManager
    }

    public var body: some View {
        VStack {
            Text(item.name)
                .font(.title)
                .foregroundStyle(.secondary)
                .padding(.vertical)
                .accessibilityIdentifier("cardNameText")
                .accessibilityLabel("Card name: \(item.name)")
                .accessibilityAddTraits(.isHeader)

            BarcodeView(barcodeString: item.code, barcodeType: item.getBarcodeType())
                .accessibilityLabel("Barcode for \(item.name)")

            Spacer()

            Text("\(item.code)")
                .font(.largeTitle)
                .accessibilityIdentifier("cardCodeText")
                .accessibilityLabel("Card code: \(item.code)")
                .accessibilityAddTraits(.isStaticText)

            Spacer()

            Text("\(item.timestamp, format: Date.FormatStyle(date: .long, time: .complete))")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("cardTimestampText")
                .accessibilityLabel("Created on \(item.timestamp, format: Date.FormatStyle(date: .long, time: .shortened))")
                .accessibilityAddTraits(.isStaticText)

            Spacer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardDetailView")
        .onAppear {
            guard brightnessBoost else { return }
            originalBrightness = UIScreen.current?.brightness ?? originalBrightness
            Task {
                await fadeBrightness(to: 1.0, duration: 0.5)
            }
            UIAccessibility.post(notification: .announcement, argument: "Screen brightness increased for better barcode visibility")
        }
        .onDisappear {
            guard brightnessBoost else { return }
            Task {
                await fadeBrightness(to: originalBrightness, duration: 0.2)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    brightnessBoost.toggle()
                    if brightnessBoost {
                        originalBrightness = UIScreen.current?.brightness ?? originalBrightness
                        Task {
                            await fadeBrightness(to: 1.0, duration: 0.5)
                        }
                        UIAccessibility.post(notification: .announcement, argument: "Brightness boost on")
                    } else {
                        Task {
                            await fadeBrightness(to: originalBrightness, duration: 0.2)
                        }
                        UIAccessibility.post(notification: .announcement, argument: "Brightness boost off")
                    }
                } label: {
                    Image(systemName: brightnessBoost ? "sun.max.fill" : "sun.max")
                        .foregroundStyle(brightnessBoost ? Color.accentColor : .primary)
                }
                .accessibilityIdentifier("brightnessToggleButton")
                .accessibilityLabel("Brightness Boost")
                .accessibilityHint("Toggles screen brightness to maximum for easier barcode scanning")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    navigationManager.navigate(to: .editCard(item.code))
                }
                .accessibilityIdentifier("editCardButton")
                .accessibilityLabel("Edit card")
                .accessibilityHint("Tap to edit this card's details")
            }
        }
    }

    private func fadeBrightness(to targetBrightness: CGFloat, duration: TimeInterval) async {
        let stepTime: TimeInterval = 0.05
        let steps = Int(duration / stepTime)
        let currentBrightness = UIScreen.current?.brightness ?? targetBrightness
        let brightnessChange = (targetBrightness - currentBrightness) / CGFloat(steps)

        for _ in 0..<steps {
            let newBrightness = (UIScreen.current?.brightness ?? targetBrightness) + brightnessChange
            UIScreen.current?.brightness = max(0.0, min(1.0, newBrightness))
            try? await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000))
        }

        UIScreen.current?.brightness = targetBrightness
    }
}

#Preview {
    let item = CardItem(timestamp: Date(), code: "123ABC", name: "Westway", barcodeType: BarcodeType.code128)
    CardItemView(item: item, navigationManager: NavigationManager())
}
