import SwiftUI

/// The open source software the app is built with, each row opening its
/// licence (PLAT-12). Opened from Settings.
public struct AcknowledgementsView: View {
    private let libraries: [OpenSourceLibrary]

    public init(libraries: [OpenSourceLibrary]) {
        self.libraries = libraries
    }

    public var body: some View {
        List {
            Section {
                ForEach(libraries) { library in
                    NavigationLink {
                        OpenSourceLicenceView(library: library)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: library.name)
                                .foregroundStyle(Color.primaryText)
                            Text(verbatim: library.licenceName)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                    .accessibilityIdentifier("libraryRow")
                }
            } footer: {
                Text(
                    "Card Barcodes is built with this open source software. Each row opens its licence.",
                    comment: "Under the list of open source software on the Acknowledgements screen. Card Barcodes is the app's name."
                )
                .foregroundStyle(Color.secondaryText)
                .accessibilityIdentifier("acknowledgementsFooter")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(
            Text(
                "Acknowledgements",
                comment: "Settings row, and the title of the screen it opens, listing the open source software the app is built with."
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("acknowledgementsView")
    }
}

#if DEBUG
#Preview("RSBarcodes_Swift") {
    NavigationStack {
        AcknowledgementsView(libraries: OpenSourceLibrary.all)
    }
}

#Preview("Several libraries") {
    NavigationStack {
        AcknowledgementsView(libraries: OpenSourceLibrary.all + [
            OpenSourceLibrary(name: "Little Fern Kit", url: nil, licenceName: "Apache License 2.0", licenceText: "Copyright 2026 Little Fern Bakery")
        ])
    }
}
#endif
