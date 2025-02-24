import SwiftUI
import UIKit // Import UIKit for UIScreen
import SwiftData

struct CardItemView: View {
    @State private var originalBrightness: CGFloat = UIScreen.main.brightness
    @State private var isEditingName = false // Control navigation to EditNameView
    @State private var item: CardItem // Make item a @State variable so changes are seen
    
    init(item: CardItem) {
        _item = State(initialValue: item)
    }
    
    var body: some View {
        VStack {
            Text(item.name)
                .font(.title).foregroundStyle(.secondary).padding(.vertical)

            BarcodeView(barcodeString: item.code, barcodeType:item.barcodeType)
            Spacer()
            Text("\(item.code)").font(.largeTitle)
            Spacer()
            Text("\(item.timestamp, format: Date.FormatStyle(date: .long, time: .complete))").foregroundStyle(.secondary)
            Spacer()
        }
        .onAppear {
            originalBrightness = UIScreen.main.brightness
            Task {
                await fadeBrightness(to: 1.0, duration: 0.5)
            }
        }
        .onDisappear {
            Task {
                await fadeBrightness(to: originalBrightness, duration: 0.2)
            }
        }.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    EditCardItemView(cardItem: item)
                        .navigationTitle("Edit Card")
                        
                } label: {
                    Text("Edit")
                        .accessibilityIdentifier("editCardButton")
                }
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
    CardItemView(item: item)
}
