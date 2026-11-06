import SwiftUI

#Preview("None chosen") {
    @Previewable @State var symbol: String?
    CardSymbolPicker(selection: $symbol, color: .blue)
}

#Preview("Basket chosen") {
    @Previewable @State var symbol: String? = "basket.fill"
    CardSymbolPicker(selection: $symbol, color: .teal)
}
