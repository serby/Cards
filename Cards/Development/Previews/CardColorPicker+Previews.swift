import SwiftUI

#Preview {
    @Previewable @State var color = CardColor.blue
    Form {
        Section("Colour") {
            CardColorPicker(selection: $color)
        }
    }
}
