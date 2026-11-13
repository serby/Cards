import SwiftUI

/// A card's barcode on the watch (WATCH-3), drawn from the modules the iPhone
/// sent, black on a white plate with the quiet zone a scanner needs. Each
/// module takes a whole number of the screen's pixels where they fit, so every
/// bar has the same width and sharp edges at any size. A square code stays
/// square, and a strip runs as wide as the plate. Without modules, the code
/// could not be drawn, and the plate says so.
struct WatchBarcodeView: View {
    static let cornerRadius: CGFloat = 8
    /// A strip barcode's plate is twice as wide as it is high.
    static let stripAspectRatio: CGFloat = 2
    /// The white above and below a strip's bars, as a share of the plate's height.
    static let stripMargin: CGFloat = 0.12

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
            .background(CardPanel.fill, in: .rect(cornerRadius: Self.cornerRadius))
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
        return width == 0 || Self.fits(modules, type: type, width: width, scale: displayScale)
    }

    @ViewBuilder
    private var content: some View {
        if let modules, drawsModules {
            let type = type
            let scale = displayScale
            Canvas { context, size in
                context.fill(Self.path(of: modules, type: type, in: size, scale: scale), with: .color(.black))
            }
            .aspectRatio(Self.aspectRatio(of: modules, type: type), contentMode: .fit)
        } else {
            failureText
                .font(.footnote)
                .foregroundStyle(CardPanel.ink)
                .multilineTextAlignment(.center)
                .padding(10)
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
    /// Whether each module gets at least a whole pixel across `width` points.
    /// One with less would be drawn between pixels and blur to grey, which no
    /// scanner reads, so the plate says it cannot be drawn instead.
    static func fits(_ modules: BarcodeModules, type: BarcodeType, width: CGFloat, scale: CGFloat) -> Bool {
        width * scale / (CGFloat(modules.columns) + CGFloat(type.quietZone * 2)) >= 1
    }

    static func aspectRatio(of modules: BarcodeModules, type: BarcodeType) -> CGFloat {
        guard modules.rows > 1 else { return stripAspectRatio }
        let quiet = CGFloat(type.quietZone * 2)
        return (CGFloat(modules.columns) + quiet) / (CGFloat(modules.rows) + quiet)
    }

    /// The dark modules as rectangles on a plate of `size` points, centred
    /// inside the quiet zone, each run of dark modules in a row as one
    /// rectangle so no seam shows between them. Module sizes and edges fall on
    /// whole pixels at `scale` when each module gets at least one.
    static func path(of modules: BarcodeModules, type: BarcodeType, in size: CGSize, scale: CGFloat) -> Path {
        let isStrip = modules.rows == 1
        let quiet = CGFloat(type.quietZone * 2)
        let across = size.width / (CGFloat(modules.columns) + quiet)
        let fit = isStrip ? across : min(across, size.height / (CGFloat(modules.rows) + quiet))
        let pixels = (fit * scale).rounded(.down)
        let module = pixels >= 1 ? pixels / scale : fit
        let snap = { (value: CGFloat) in (value * scale).rounded() / scale }

        let left = snap((size.width - module * CGFloat(modules.columns)) / 2)
        let top = isStrip ? snap(size.height * stripMargin) : snap((size.height - module * CGFloat(modules.rows)) / 2)
        let rowHeight = isStrip ? size.height - top * 2 : module

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
                    x: left + CGFloat(start) * module,
                    y: top + CGFloat(row) * rowHeight,
                    width: CGFloat(column - start) * module,
                    height: rowHeight
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
