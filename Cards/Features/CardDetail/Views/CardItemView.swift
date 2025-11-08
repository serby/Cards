import SwiftData
import SwiftUI
import UIKit // Import UIKit for UIScreen

struct CardItemView: View {
    @State private var originalBrightness: CGFloat = UIScreen.main.brightness
    @State private var item: CardItem // Make item a @State variable so changes are seen
    let navigationManager: NavigationManager
    
    init(item: CardItem, navigationManager: NavigationManager) {
        _item = State(initialValue: item)
        self.navigationManager = navigationManager
    }
    
    var body: some View {
        VStack {
            Text(item.name)
                .font(.title)
                .foregroundStyle(.secondary)
                .padding(.vertical)
                .accessibilityIdentifier("cardNameText")
                .accessibilityLabel("Card name: \(item.name)")
                .accessibilityAddTraits(.isHeader)

            BarcodeView(barcodeString: item.code, barcodeType: item.getBarcodeType())
                .accessibilityIdentifier("barcodeView")
                .accessibilityLabel("Barcode for \(item.name)")
                .accessibilityHint("This is a \(item.getBarcodeType().rawValue) barcode with code \(item.code)")
            
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
            originalBrightness = UIScreen.main.brightness
            Task {
                await fadeBrightness(to: 1.0, duration: 0.5)
            }
            
            // Announce to VoiceOver users that screen brightness has increased
            UIAccessibility.post(notification: .announcement, argument: "Screen brightness increased for better barcode visibility")
        }
        .onDisappear {
            Task {
                await fadeBrightness(to: originalBrightness, duration: 0.2)
            }
        }
        .toolbar {
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
        let stepTime: TimeInterval = 0.05 // Update interval in seconds
        let steps = Int(duration / stepTime) // Total number of updates
        let currentBrightness = UIScreen.main.brightness
        let brightnessChange = (targetBrightness - currentBrightness) / CGFloat(steps)
        
        for _ in 0..<steps {
            let newBrightness = UIScreen.main.brightness + brightnessChange
            UIScreen.main.brightness = max(0.0, min(1.0, newBrightness)) // Clamp between 0.0 and 1.0
            try? await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000)) // Sleep for stepTime
        }
        
        // Ensure final brightness is exact
        UIScreen.main.brightness = targetBrightness
    }
}

#Preview {
    let item = CardItem(timestamp: Date(), code: "123ABC", name: "Westway", barcodeType: BarcodeType.code128)
    CardItemView(item: item, navigationManager: NavigationManager())
}
