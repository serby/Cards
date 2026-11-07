import SwiftUI

/// Development > Language (DEV-4): opens the app in any language it has, or
/// back in the iPhone's, without changing the iPhone's own settings. iOS
/// chooses an app's language only when it opens it, so choosing one closes the
/// app, after saying so.
struct LanguageScreen: View {
    @Environment(\.appLanguageClient) private var client
    /// The choice waiting for the alert's answer.
    @State private var pending: LanguageChoice?
    private let choices = LanguageChoice.all()

    var body: some View {
        let current = LanguageChoice.current(for: client.override(), in: choices)
        List {
            Section {
                ForEach(choices) { choice in
                    Button {
                        if choice != current {
                            pending = choice
                        }
                    } label: {
                        row(for: choice, isCurrent: choice == current)
                    }
                    .accessibilityAddTraits(choice == current ? .isSelected : [])
                    .accessibilityIdentifier("languageChoice-\(choice.id)")
                }
            } footer: {
                Text(verbatim: Self.footer)
                    .foregroundColor(.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground)
        .navigationTitle(Text(verbatim: "Language"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(Text(verbatim: pending?.confirmationTitle ?? ""), isPresented: isConfirming, presenting: pending) { choice in
            Button(String("Close Card Barcodes")) {
                client.open(in: choice)
            }
            .accessibilityIdentifier("closeForLanguageButton")
            Button(String("Cancel"), role: .cancel) {}
        } message: { choice in
            Text(verbatim: choice.confirmationMessage)
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
    }

    private func row(for choice: LanguageChoice, isCurrent: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: choice.name)
                    .foregroundColor(.primaryText)
                if let detail = choice.detail {
                    Text(verbatim: detail)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark")
                    .foregroundColor(.accent)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    private static let footer = """
        Only the app's language changes. The region stays as it is, so distances on Automatic keep their units, \
        and dates and times keep the region's clock and calendar. The Home Screen widget stays in the iPhone's language, \
        as it runs on its own and does not read this choice.
        """
}

#if DEBUG
#Preview("System") {
    @Previewable @State var box = LanguageOverrideBox()
    NavigationStack {
        LanguageScreen()
    }
    .environment(\.appLanguageClient, .simulated(box))
}

#Preview("Deutsch") {
    @Previewable @State var box = LanguageOverrideBox(override: ["de"])
    NavigationStack {
        LanguageScreen()
    }
    .environment(\.appLanguageClient, .simulated(box))
}
#endif
