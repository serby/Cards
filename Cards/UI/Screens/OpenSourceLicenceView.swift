import SwiftUI

/// One open source library's licence in full, opened from Settings >
/// Acknowledgements (PLAT-12). The licence is shown as its project wrote it,
/// in English, and can be selected and copied.
public struct OpenSourceLicenceView: View {
    private let library: OpenSourceLibrary

    public init(library: OpenSourceLibrary) {
        self.library = library
    }

    public var body: some View {
        List {
            Section {
                Text(verbatim: library.licenceText)
                    .font(.callout)
                    .foregroundStyle(Color.primaryText)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("licenceText")
            } header: {
                Text(verbatim: library.licenceName)
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("licenceName")
            }
            if let url = library.url {
                Section {
                    Link(destination: url) {
                        HStack {
                            Text("Project Website", comment: "Row under an open source licence that opens the library's project page.")
                                .foregroundStyle(Color.primaryText)
                            Spacer()
                            // The link trait and the hint say where it goes; the
                            // arrow says it again for sighted users only.
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundStyle(Color.accent)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint(
                        Text("Opens in your web browser", comment: "VoiceOver hint for the row that opens an open source library's project page.")
                    )
                    .accessibilityIdentifier("projectWebsiteLink")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text(verbatim: library.name))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("openSourceLicenceView")
    }
}

#if DEBUG
#Preview("RSBarcodes_Swift") {
    NavigationStack {
        OpenSourceLicenceView(library: .rsBarcodes)
    }
}

#Preview("No project website") {
    NavigationStack {
        OpenSourceLicenceView(
            library: OpenSourceLibrary(
                name: "Little Fern Kit",
                url: nil,
                licenceName: "MIT License",
                licenceText: OpenSourceLibrary.rsBarcodes.licenceText
            )
        )
    }
}
#endif
