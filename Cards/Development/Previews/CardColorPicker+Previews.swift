import SwiftUI

#Preview {
    @Previewable @State var color = CardColor.blue
    Form {
        Section {
            CardColorPicker(selection: $color)
        } header: {
            Text(verbatim: "Colour")
        }
    }
}
