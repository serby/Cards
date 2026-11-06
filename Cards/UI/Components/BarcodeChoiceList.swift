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
                    .accessibilityLabel(barcode.type.rawValue)
                    .accessibilityValue(Text(barcode.code).speechSpellsOutCharacters())
                    .accessibilityHint("Fills in this code and type")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("barcodeChoice_\(index)")
                }
            } footer: {
                Text(footer)
            }
        }
        .accessibilityIdentifier("barcodeChoiceList")
    }

    /// "3 barcodes found. Choose the one for this card."
    private var footer: String {
        let found = barcodes.count == 1 ? "1 barcode found." : "\(barcodes.count) barcodes found."
        return "\(found) Choose the one for this card."
    }

    private func row(_ barcode: FoundBarcode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(barcode.type.rawValue)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
            Text(barcode.code)
                .font(.body.monospaced())
                .foregroundStyle(Color.primaryText)
                .lineLimit(3)
                .truncationMode(.middle)
                .multilineTextAlignment(.leading)
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
