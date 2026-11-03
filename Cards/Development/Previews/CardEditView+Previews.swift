import SwiftUI

#Preview("Edit") {
    @Previewable @State var draft = CardDraft.sample
    NavigationStack {
        CardEditView(draft: $draft)
            .navigationTitle(Text(verbatim: "Edit Card"))
    }
}

#Preview("Add") {
    @Previewable @State var draft = CardDraft.empty
    NavigationStack {
        CardEditView(draft: $draft) { ScannerPlaceholderView() }
            .navigationTitle(Text(verbatim: "Add Card"))
    }
}
