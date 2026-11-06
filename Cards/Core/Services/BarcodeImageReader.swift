import ImageIO
import PDFKit
import SwiftUI
import UIKit
import Vision

/// Finds the barcodes in a picture or a PDF, such as a screenshot of a loyalty
/// card or an e-ticket, injected so nothing but the live value runs Vision (CARD-13).
public struct BarcodeImageReader: Sendable {
    /// Every barcode in an image (PNG, JPEG, HEIC and the like) or on the
    /// pages of a PDF, top to bottom and page by page. Throws when the data is
    /// neither a picture nor a PDF.
    public var read: @Sendable (Data) async throws -> [DetectedBarcode]

    public init(read: @escaping @Sendable (Data) async throws -> [DetectedBarcode]) {
        self.read = read
    }
}

public extension BarcodeImageReader {
    /// Vision's barcode detector, run on the device. A PDF's pages are drawn
    /// with PDFKit first, sharp enough to read a small barcode.
    static let live = Self { data in
        if BarcodeImagePages.isPDF(data) {
            var found: [DetectedBarcode] = []
            for page in try BarcodeImagePages.pdfPages(data) {
                found += try await detect(in: page)
            }
            return found
        }
        return try await detect(in: BarcodeImagePages.image(data))
    }

    /// The barcodes Vision finds in one picture, top to bottom. Codes Vision
    /// can see but not decode are left out, since there is nothing to fill in.
    private static func detect(in image: CGImage) async throws -> [DetectedBarcode] {
        try await DetectBarcodesRequest().perform(on: image)
            .sorted { $0.boundingBox.cgRect.maxY > $1.boundingBox.cgRect.maxY }
            .compactMap { observation in
                guard let code = observation.payloadString, !code.isEmpty else { return nil }
                let symbology = observation.symbology
                return DetectedBarcode(code: code, type: symbology.barcodeType, kind: symbology.name)
            }
    }
}

/// Turns a file's data into the pictures Vision reads.
enum BarcodeImagePages {
    enum Failure: Error {
        case notAnImage
        case notAPDF
    }

    /// The longest side, in pixels, a picture or page is drawn at. Big enough
    /// to read a small barcode on an A4 page, small enough to stay light.
    static let longestSide: CGFloat = 4_096
    /// How many pixels a PDF page gets per point: 4 is 288 dots per inch.
    static let pdfScale: CGFloat = 4
    /// A ticket or a membership PDF has a page or two; a long document is read
    /// only this far.
    static let maximumPDFPages = 20

    /// Whether the data starts the way every PDF does.
    static func isPDF(_ data: Data) -> Bool {
        data.starts(with: Data("%PDF".utf8))
    }

    /// The picture in an image file, the right way up and no bigger than
    /// `longestSide`, so a 48 megapixel photo does not fill the memory.
    static func image(_ data: Data) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure.notAnImage
        }
        return image
    }

    /// Each page of a PDF, drawn on white, up to `maximumPDFPages`.
    static func pdfPages(_ data: Data) throws -> [CGImage] {
        guard let document = PDFDocument(data: data) else { throw Failure.notAPDF }
        let count = min(document.pageCount, maximumPDFPages)
        return (0..<count).compactMap { index in
            document.page(at: index).flatMap(render)
        }
    }

    private static func render(_ page: PDFPage) -> CGImage? {
        let box = page.bounds(for: .mediaBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scale = min(pdfScale, longestSide / max(box.width, box.height))
        let size = CGSize(width: (box.width * scale).rounded(), height: (box.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            // PDF space has its origin at the bottom left; UIKit's is at the top.
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        return image.cgImage
    }
}

extension BarcodeSymbology {
    /// The app's type for this symbology, or nil when the app cannot draw it.
    /// The checksum and full ASCII forms of Code 39 and Code 93 are drawn as
    /// plain Code 39 and Code 93, which carry the same characters.
    var barcodeType: BarcodeType? {
        switch self {
        case .code128:
            .code128
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum:
            .code39
        case .code93, .code93i:
            .code93
        case .qr:
            .qrCode
        case .ean8:
            .ean8
        case .ean13:
            .ean13
        case .upce:
            .upce
        case .aztec:
            .aztec
        case .pdf417:
            .pdf417
        default:
            nil
        }
    }

    /// What people call this kind of barcode, such as "Data Matrix", to say
    /// which kind the app cannot show. Nil for a kind added after this build.
    var name: String? {
        if let barcodeType {
            return barcodeType.rawValue
        }
        switch self {
        case .dataMatrix:
            return "Data Matrix"
        case .itf14:
            return "ITF-14"
        case .i2of5, .i2of5Checksum:
            return "Interleaved 2 of 5"
        case .codabar:
            return "Codabar"
        case .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited:
            return "GS1 DataBar"
        case .microQR:
            return "Micro QR"
        case .microPDF417:
            return "MicroPDF417"
        case .msiPlessey:
            return "MSI Plessey"
        default:
            return nil
        }
    }
}

private struct BarcodeImageReaderKey: EnvironmentKey {
    static let defaultValue = BarcodeImageReader.live
}

public extension EnvironmentValues {
    var barcodeImageReader: BarcodeImageReader {
        get { self[BarcodeImageReaderKey.self] }
        set { self[BarcodeImageReaderKey.self] = newValue }
    }
}
