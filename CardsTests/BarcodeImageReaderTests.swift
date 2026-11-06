@testable import Cards
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
import Vision

/// Vision cannot make its barcode detector in the simulator: iOS 18.1 and
/// 27.0 both fail with "Failed to create barcode detector.", which is how CI
/// runs. So reading through Vision is tested on a device, and the simulator
/// tests everything round it.
enum VisionBarcodeDetector {
    static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }
}

/// Adding a card from a photo or a file (CARD-13), through Vision: the live
/// reader finds the barcodes Core Image draws, in pictures and in PDFs.
@Suite(.enabled(if: VisionBarcodeDetector.isAvailable, "Vision cannot make its barcode detector in the simulator"))
struct BarcodeImageReaderVisionTests {

    @Test(arguments: [
        (BarcodeType.code128, "LRC-0042-7781"),
        (.qrCode, "BOULDERBARN-10442"),
        (.pdf417, "HONEYCOMB 77812"),
        (.aztec, "JOESMARKET-4417")
    ])
    func theLiveReaderFindsAGeneratedBarcode(type: BarcodeType, code: String) async throws {
        let picture = try #require(GeneratedBarcode.image(type, code).pngData())

        let detected = try await BarcodeImageReader.live.read(picture)

        #expect(detected.first == DetectedBarcode(code: code, type: type))
        #expect(BarcodeReading(detected) == .found([FoundBarcode(code: code, type: type)]))
    }

    @Test func aPhotoInAnotherFormatIsReadToo() async throws {
        let photo = try #require(GeneratedBarcode.image(.qrCode, "BOULDERBARN-10442").jpegData(compressionQuality: 0.8))

        let detected = try await BarcodeImageReader.live.read(photo)

        #expect(BarcodeReading(detected) == .found([FoundBarcode(code: "BOULDERBARN-10442", type: .qrCode)]))
    }

    @Test func twoBarcodesInOnePictureAreFoundTopToBottom() async throws {
        let strip = GeneratedBarcode.image(.code128, "LRC-0042-7781")
        let square = GeneratedBarcode.image(.qrCode, "BOULDERBARN-10442")
        let size = CGSize(width: max(strip.size.width, square.size.width), height: strip.size.height + 200 + square.size.height)
        let picture = try #require(GeneratedBarcode.draw(size) {
            strip.draw(at: .zero)
            square.draw(at: CGPoint(x: 0, y: strip.size.height + 200))
        }.pngData())

        let detected = try await BarcodeImageReader.live.read(picture)

        #expect(BarcodeReading(detected) == .found([
            FoundBarcode(code: "LRC-0042-7781", type: .code128),
            FoundBarcode(code: "BOULDERBARN-10442", type: .qrCode)
        ]))
    }

    @Test func aPictureWithNoBarcodeFindsNothing() async throws {
        let blank = try #require(GeneratedBarcode.draw(CGSize(width: 600, height: 400)) {}.pngData())

        let detected = try await BarcodeImageReader.live.read(blank)

        #expect(detected.isEmpty)
        #expect(BarcodeReading(detected) == .nothing)
    }

    /// The strip barcode on the ticket's second page is too fine to read at
    /// 72 dots per inch, so this also checks that pages are drawn sharp enough.
    @Test func aPDFIsReadPageByPage() async throws {
        let detected = try await BarcodeImageReader.live.read(GeneratedBarcode.ticket())

        #expect(BarcodeReading(detected) == .found([
            FoundBarcode(code: "BOULDERBARN-10442", type: .qrCode),
            FoundBarcode(code: "LRC-0042-7781", type: .code128)
        ]))
    }
}

/// Adding a card from a photo or a file (CARD-13): how a picture or a PDF is
/// prepared for Vision, what Vision's kinds of barcode become, how what it
/// finds is sorted into what the form can fill in, and the add form's connector.
struct BarcodeImageReaderTests {

    // MARK: Preparing pictures and pages

    @Test func dataThatIsNeitherAPictureNorAPDFCannotBeRead() async {
        let text = Data("Joe's Market".utf8)

        #expect(!BarcodeImagePages.isPDF(text))
        await #expect(throws: BarcodeImagePages.Failure.notAnImage) {
            try await BarcodeImageReader.live.read(text)
        }
    }

    @Test func aPictureIsReadAtItsOwnSizeUpTo4096PixelsAcross() throws {
        let screenshot = try #require(GeneratedBarcode.draw(CGSize(width: 1_179, height: 2_556)) {}.pngData())
        let panorama = try #require(GeneratedBarcode.draw(CGSize(width: 6_000, height: 1_500)) {}.pngData())

        let small = try BarcodeImagePages.image(screenshot)
        let large = try BarcodeImagePages.image(panorama)

        #expect((small.width, small.height) == (1_179, 2_556))
        #expect((large.width, large.height) == (4_096, 1_024))
    }

    /// A photo taken with the phone on its side is stored sideways with an
    /// orientation; it is read the way it is shown.
    @Test func aPhotoIsReadTheRightWayUp() throws {
        let sideways = try #require(GeneratedBarcode.draw(CGSize(width: 600, height: 400)) {}.cgImage)
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, sideways, [kCGImagePropertyOrientation: 6] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))

        let photo = try BarcodeImagePages.image(data as Data)

        #expect((photo.width, photo.height) == (400, 600))
    }

    /// Each A4 page is drawn on white at 288 dots per inch, the right way up:
    /// the QR code at the top left of the first page is dark there, and the
    /// same place at the bottom of the page is white.
    @Test func aPDFsPagesAreDrawnOnWhiteAt288DotsPerInch() throws {
        let pages = try BarcodeImagePages.pdfPages(GeneratedBarcode.ticket())

        #expect(pages.map(\.width) == [2_380, 2_380])
        #expect(pages.map(\.height) == [3_368, 3_368])
        let page = try #require(pages.first)
        #expect(GeneratedBarcode.darkness(of: page, in: CGRect(x: 240, y: 400, width: 560, height: 560)) > 0.1)
        #expect(GeneratedBarcode.darkness(of: page, in: CGRect(x: 240, y: 2_408, width: 560, height: 560)) == 0)
        #expect(GeneratedBarcode.darkness(of: page, in: CGRect(x: 1_400, y: 1_600, width: 600, height: 600)) == 0)
    }

    @Test func onlyTheFirst20PagesOfALongPDFAreRead() throws {
        let long = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 100)).pdfData { context in
            for _ in 0..<25 {
                context.beginPage()
            }
        }

        #expect(try BarcodeImagePages.pdfPages(long).count == 20)
    }

    // MARK: What Vision's kinds of barcode become

    @Test func everyTypeTheAppDrawsCanBeReadFromAPicture() {
        for type in BarcodeType.allCases {
            #expect(BarcodeSymbology.allCases.contains { $0.barcodeType == type }, "\(type.rawValue)")
        }
    }

    @Test(arguments: [
        (BarcodeSymbology.code128, BarcodeType.code128),
        (.code39, .code39),
        (.code39Checksum, .code39),
        (.code39FullASCII, .code39),
        (.code39FullASCIIChecksum, .code39),
        (.code93, .code93),
        (.code93i, .code93),
        (.qr, .qrCode),
        (.ean8, .ean8),
        (.ean13, .ean13),
        (.upce, .upce),
        (.aztec, .aztec),
        (.pdf417, .pdf417)
    ])
    func aKindTheAppDrawsMapsToItsType(symbology: BarcodeSymbology, type: BarcodeType) {
        #expect(symbology.barcodeType == type)
        #expect(symbology.name == type.rawValue)
    }

    /// Vision also lists kinds its interface does not name, such as App Clip
    /// Codes; those have no name, and the form says "this kind of barcode".
    @Test(arguments: [
        (BarcodeSymbology.dataMatrix, "Data Matrix"),
        (.itf14, "ITF-14"),
        (.i2of5, "Interleaved 2 of 5"),
        (.i2of5Checksum, "Interleaved 2 of 5"),
        (.codabar, "Codabar"),
        (.gs1DataBar, "GS1 DataBar"),
        (.gs1DataBarExpanded, "GS1 DataBar"),
        (.gs1DataBarLimited, "GS1 DataBar"),
        (.microQR, "Micro QR"),
        (.microPDF417, "MicroPDF417"),
        (.msiPlessey, "MSI Plessey")
    ])
    func aKindTheAppCannotDrawIsNamed(symbology: BarcodeSymbology, name: String) {
        #expect(symbology.barcodeType == nil)
        #expect(symbology.name == name)
    }

    // MARK: Sorting what was found

    @Test func aCodeFoundTwiceIsOfferedOnce() {
        let ticket = DetectedBarcode(code: "BOULDERBARN-10442", type: .qrCode)
        let till = DetectedBarcode(code: "2900417730126", type: .ean13)

        #expect(BarcodeReading([ticket, till, ticket]) == .found([
            FoundBarcode(code: "BOULDERBARN-10442", type: .qrCode),
            FoundBarcode(code: "2900417730126", type: .ean13)
        ]))
    }

    @Test func aBarcodeTheAppCanShowWinsOverOneItCannot() {
        let matrix = DetectedBarcode(code: "NN-WEMBLEY-88", type: nil, kind: "Data Matrix")
        let strip = DetectedBarcode(code: "LRC-0042-7781", type: .code128)

        #expect(BarcodeReading([matrix, strip]) == .found([FoundBarcode(code: "LRC-0042-7781", type: .code128)]))
    }

    @Test func onlyKindsTheAppCannotShowAreNamedOnce() {
        let matrix = DetectedBarcode(code: "NN-WEMBLEY-88", type: nil, kind: "Data Matrix")
        let other = DetectedBarcode(code: "NN-WEMBLEY-89", type: nil, kind: "Data Matrix")
        let itf = DetectedBarcode(code: "10012345000017", type: nil, kind: "ITF-14")
        let newer = DetectedBarcode(code: "LL-0001", type: nil, kind: nil)

        #expect(BarcodeReading([matrix, other, itf]) == .unsupported(["Data Matrix", "ITF-14"]))
        #expect(BarcodeReading([newer]) == .unsupported([]))
        #expect(BarcodeReading([]) == .nothing)
    }

    @Test func eachProblemIsSaidPlainly() {
        #expect(BarcodeReading.found([FoundBarcode(code: "LRC-0042-7781", type: .code128)]).problem == nil)
        #expect(problem(.nothing) == "No barcode found. Try a picture where the whole barcode is sharp.")
        #expect(problem(.unsupported(["Data Matrix"])) == "Card Barcodes cannot show Data Matrix codes.")
        #expect(problem(.unsupported(["Data Matrix", "ITF-14"])) == "Card Barcodes cannot show Data Matrix or ITF-14 codes.")
        #expect(problem(.unsupported([])) == "Card Barcodes cannot show this kind of barcode.")
        #expect(problem(.unreadable) == "That photo or file could not be read.")
        #expect(FoundBarcode(code: "LRC-0042-7781", type: .code128).announcement == "Barcode found: Code 128. Its code is filled in.")
    }

    /// The problem as the form shows it, in the English the tests run in.
    private func problem(_ reading: BarcodeReading) -> String? {
        reading.problem.map { String(localized: $0) }
    }

    // MARK: The add form's connector, through stand-in clients

    @MainActor
    @Test func aChosenFileIsReadForBarcodes() async {
        let file = FileReader { _ in Data("%PDF-1.7".utf8) }
        let ticket = BarcodeImageReader { data in
            #expect(data == Data("%PDF-1.7".utf8))
            return [
                DetectedBarcode(code: "BOULDERBARN-10442", type: .qrCode),
                DetectedBarcode(code: "LRC-0042-7781", type: .code128)
            ]
        }

        let reading = await CardEditScreen.readFile(.success(URL(filePath: "/tmp/ticket.pdf")), files: file, barcodes: ticket)

        #expect(reading == .found([
            FoundBarcode(code: "BOULDERBARN-10442", type: .qrCode),
            FoundBarcode(code: "LRC-0042-7781", type: .code128)
        ]))
    }

    @MainActor
    @Test func aFileThatCannotBeOpenedOrReadIsUnreadable() async {
        let file = FileReader { _ in Data("Joe's Market".utf8) }
        let unopenable = FileReader { _ in throw CocoaError(.fileReadNoPermission) }
        let notAPicture = BarcodeImageReader { _ in throw BarcodeImagePages.Failure.notAnImage }
        let neverRead = BarcodeImageReader { _ in
            Issue.record("Nothing should be read when no file was chosen")
            return []
        }

        let cancelled = await CardEditScreen.readFile(.failure(CocoaError(.userCancelled)), files: file, barcodes: neverRead)
        let refused = await CardEditScreen.readFile(.success(URL(filePath: "/tmp/card.png")), files: unopenable, barcodes: neverRead)
        let text = await CardEditScreen.readFile(.success(URL(filePath: "/tmp/notes.txt")), files: file, barcodes: notAPicture)

        #expect(cancelled == .unreadable)
        #expect(refused == .unreadable)
        #expect(text == .unreadable)
    }

    @MainActor
    @Test func noPhotoDataIsUnreadable() async {
        #expect(await CardEditScreen.read(nil, barcodes: .live) == .unreadable)
    }
}

/// Barcodes drawn with Core Image, as a screenshot or a PDF shows them.
enum GeneratedBarcode {
    /// The barcode at `scale` pixels a module, on white with a margin round it.
    static func image(_ type: BarcodeType, _ code: String, scale: CGFloat = 6) -> UIImage {
        guard let bars = bars(type, code)?.samplingNearest().transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let drawn = CIContext().createCGImage(bars, from: bars.extent) else {
            Issue.record("Core Image could not draw a \(type.rawValue) of \(code)")
            return UIImage()
        }
        let margin: CGFloat = 40
        let size = CGSize(width: CGFloat(drawn.width) + margin * 2, height: CGFloat(drawn.height) + margin * 2)
        return draw(size) {
            UIImage(cgImage: drawn).draw(at: CGPoint(x: margin, y: margin))
        }
    }

    /// A two-page A4 e-ticket: a QR code at the top left of the first page,
    /// and a strip barcode 150 points (about 5 cm) wide on the second.
    static func ticket() -> Data {
        let square = image(.qrCode, "BOULDERBARN-10442")
        let strip = image(.code128, "LRC-0042-7781")
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()
            "Boulder Barn day pass".draw(at: CGPoint(x: 60, y: 60), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            square.draw(in: CGRect(x: 60, y: 100, width: 140, height: 140))
            context.beginPage()
            strip.draw(in: CGRect(x: 60, y: 600, width: 150, height: 150 * strip.size.height / strip.size.width))
        }
    }

    /// The share of pixels in `rect`, measured from the top left, darker than mid grey.
    static func darkness(of image: CGImage, in rect: CGRect) -> Double {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return .nan }
        // The bitmap's first row is the top of the picture.
        var dark = 0
        var total = 0
        for row in Int(rect.minY)..<Int(rect.maxY) {
            for column in Int(rect.minX)..<Int(rect.maxX) {
                let offset = (row * width + column) * 4
                let brightness = (Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])) / 3
                dark += brightness < 128 ? 1 : 0
                total += 1
            }
        }
        return Double(dark) / Double(total)
    }

    /// A white picture of `size` pixels, with `content` drawn on it.
    static func draw(_ size: CGSize, _ content: () -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            content()
        }
    }

    private static func bars(_ type: BarcodeType, _ code: String) -> CIImage? {
        let message = Data(code.utf8)
        switch type {
        case .code128:
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = message
            return filter.outputImage
        case .qrCode:
            let filter = CIFilter.qrCodeGenerator()
            filter.message = message
            filter.correctionLevel = "M"
            return filter.outputImage
        case .pdf417:
            let filter = CIFilter.pdf417BarcodeGenerator()
            filter.message = message
            return filter.outputImage
        case .aztec:
            let filter = CIFilter.aztecCodeGenerator()
            filter.message = message
            return filter.outputImage
        default:
            return nil
        }
    }
}
