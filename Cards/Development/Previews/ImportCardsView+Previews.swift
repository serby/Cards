import SwiftUI

#Preview("Empty") {
    @Previewable @State var text = ""
    ImportCardsView(importText: $text) {}
}

#Preview("Pasted export") {
    @Previewable @State var text = #"[{"code": "9988776655443", "name": "Nectar"}]"#
    ImportCardsView(importText: $text) {}
}
