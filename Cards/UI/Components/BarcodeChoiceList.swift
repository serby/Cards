import SwiftUI

/// The barcodes found in one photo or file, each with its type and code, to
/// choose the one for the card (CARD-13). Tapping one chooses it.
public struct BarcodeChoiceList: View {
    private let barcodes: [FoundBarcode]
    private let onChoose: (FoundBarcode) -> Void

    public init(barcodes: [FoundBarcode], onChoose: @escaping (FoundBarcode) -> Void = { _ in }) {
        self.barcodes = barcodes
        self.onChoose = onChoose
    }

    public var body: some View {
        List {
            Section {
                ForEach(Array(barcodes.enumerated()), id: \.element.id) { index, barcode in
                    Button {
                        onChoose(barcode)
                    } label: {
                        row(barcode)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(barcode.type.displayName))
                    .accessibilityValue(Text(barcode.code).speechSpellsOutCharacters())
                    .accessibilityHint(
                        Text(
                            "Fills in this code and type",
                            comment: "VoiceOver hint for a barcode in the list of those found in a photo or file: choosing it fills in the card form."
                        )
                    )
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("barcodeChoice_\(index)")
                }
            } footer: {
                Text(
                    "\(barcodes.count) barcodes found. Choose the one for this card.",
                    comment: """
                        Under the list of barcodes found in a photo or a file, when there are several to choose from. The argument is how \
                        many, usually two or more.
                        """
                )
            }
        }
        .accessibilityIdentifier("barcodeChoiceList")
    }

    private func row(_ barcode: FoundBarcode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(barcode.type.displayName)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
            Text(barcode.code)
                .font(.body.monospaced())
                .foregroundStyle(Color.primaryText)
                .lineLimit(3)
                .truncationMode(.middle)
                .multilineTextAlignment(.leading)
                .readsLeftToRight()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

#if DEBUG
#Preview("Two barcodes") {
    BarcodeChoiceList(barcodes: FoundBarcode.samples)
}

#Preview("A long code") {
    BarcodeChoiceList(barcodes: [FoundBarcode.longCode] + FoundBarcode.samples)
}
#endif
