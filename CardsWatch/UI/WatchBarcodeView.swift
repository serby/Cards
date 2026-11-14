import SwiftUI

/// A card's barcode on the watch (WATCH-3), drawn from the modules the iPhone
/// sent, black on a white plate that is exactly the code and the quiet zone
/// its standard requires (`BarcodePlate`), centred. Each module takes a whole
/// number of the screen's pixels, so every bar has the same width and sharp
/// edges at any size. Without modules, or with more than the screen has
/// pixels for, the plate says the code can't be drawn.
struct WatchBarcodeView: View {
    static let cornerRadius: CGFloat = 8
    /// A strip barcode's plate is this many times as wide as it is high.
    static let stripAspectRatio: CGFloat = 1.8

    let modules: BarcodeModules?
    let type: BarcodeType
    @Environment(\.displayScale) private var displayScale
    /// How wide the plate is, once laid out, to tell whether every module gets
    /// a pixel of its own.
    @State private var width: CGFloat = 0

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            // A mirrored barcode will not scan, so it stays as drawn right to left too.
            .readsLeftToRight()
            // One element that says what is shown: the barcode and its format, or
            // the failure. The code itself is read out, spelled, by the line under it.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                !drawsModules
                    ? failureText
                    : Text(
                        "Barcode",
                        comment: "VoiceOver label for the barcode on a card's screen on Apple Watch. Its format, such as EAN-13, is read after it."
                    )
            )
            .accessibilityValue(Text(type.displayName))
            .accessibilityAddTraits(drawsModules ? .isImage : [])
            .accessibilityIdentifier("watchBarcode")
            .keepsColoursWhenInverted()
    }

    /// Whether the code is drawn, rather than the message that it cannot be.
    private var drawsModules: Bool {
        guard let modules else { return false }
        return width == 0 || plate(for: modules, in: CGSize(width: width, height: .greatestFiniteMagnitude)) != nil
    }

    @ViewBuilder
    private var content: some View {
        if let modules, drawsModules {
            let type = type
            let scale = displayScale
            Canvas { context, size in
                let plate = BarcodePlate(modules: modules, type: type, fitting: size, scale: scale, stripAspectRatio: Self.stripAspectRatio)
                guard let plate else { return }
                // Centred on whole pixels, in the space left by the whole-pixel modules.
                let offset = CGPoint(
                    x: ((size.width - plate.size.width) / 2 * scale).rounded(.down) / scale,
                    y: ((size.height - plate.size.height) / 2 * scale).rounded(.down) / scale
                )
                let radius = plate.cornerRadius(upTo: Self.cornerRadius, zone: type.quietZone, isStrip: modules.rows == 1)
                context.fill(
                    Path(roundedRect: CGRect(origin: offset, size: plate.size), cornerRadius: radius),
                    with: .color(CardPanel.fill)
                )
                context.fill(Self.path(of: modules, on: plate, at: offset), with: .color(.black))
            }
            .aspectRatio(Self.aspectRatio(of: modules, type: type), contentMode: .fit)
        } else {
            failureText
                .font(.footnote)
                .foregroundStyle(CardPanel.ink)
                .multilineTextAlignment(.center)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(CardPanel.fill, in: .rect(cornerRadius: Self.cornerRadius))
        }
    }

    private var failureText: Text {
        Text(
            "This code can't be drawn",
            comment: """
                Shown on Apple Watch instead of the barcode when the card's code can't be drawn in its barcode format. \
                The code itself shows below it.
                """
        )
    }

    /// The plate's width over its height: a strip's fixed shape, or the grid's
    /// own with its quiet zone.
    private func plate(for modules: BarcodeModules, in space: CGSize) -> BarcodePlate? {
        BarcodePlate(modules: modules, type: type, fitting: space, scale: displayScale, stripAspectRatio: Self.stripAspectRatio)
    }

    /// The plate's width over its height: a strip's fixed shape, or the grid's
    /// own with its quiet zone.
    static func aspectRatio(of modules: BarcodeModules, type: BarcodeType) -> CGFloat {
        guard modules.rows > 1 else { return stripAspectRatio }
        let zone = type.quietZone
        return CGFloat(zone.leading + modules.columns + zone.trailing) / CGFloat(modules.rows + zone.vertical * 2)
    }

    /// The dark modules as rectangles on `plate`, placed at `offset`, each run
    /// of dark modules in a row as one rectangle so no seam shows between them.
    static func path(of modules: BarcodeModules, on plate: BarcodePlate, at offset: CGPoint) -> Path {
        var path = Path()
        for row in 0..<modules.rows {
            var column = 0
            while column < modules.columns {
                guard modules.isDark(column: column, row: row) else {
                    column += 1
                    continue
                }
                let start = column
                while column < modules.columns, modules.isDark(column: column, row: row) {
                    column += 1
                }
                path.addRect(CGRect(
                    x: offset.x + plate.origin.x + CGFloat(start) * plate.module,
                    y: offset.y + plate.origin.y + CGFloat(row) * plate.rowHeight,
                    width: CGFloat(column - start) * plate.module,
                    height: plate.rowHeight
                ))
            }
        }
        return path
    }

}

#if DEBUG
#Preview("Strip barcode") {
    WatchBarcodeView(modules: WatchCard.joesMarket.modules, type: .ean13)
        .padding()
}

#Preview("QR code") {
    WatchBarcodeView(modules: WatchCard.boulderBarn.modules, type: .qrCode)
        .padding()
}

#Preview("Cannot be drawn") {
    WatchBarcodeView(modules: nil, type: .ean13)
        .padding()
}
#endif
