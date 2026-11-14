@testable import Cards
import CoreGraphics
import CoreLocation
import Foundation
import Testing
import UIKit
import Vision

/// The plate is the code and its standard's quiet zone, on whole pixels, and
/// no more white than that (WATCH-3).
struct BarcodePlateTests {
    @Test(arguments: WatchSampleCodes.all)
    func thePlateIsTheCodeAndItsQuietZoneExactly(type: BarcodeType, code: String) throws {
        let modules = try #require(BarcodeModules(code: code, type: type))
        let zone = type.quietZone
        for width in [150.0, 184, 205] {
            let plate = try #require(
                BarcodePlate(modules: modules, type: type, fitting: CGSize(width: width, height: 1_000), scale: 2, stripAspectRatio: 1.8)
            )
            #expect(plate.size.width == plate.module * CGFloat(zone.leading + modules.columns + zone.trailing))
            #expect(plate.origin == CGPoint(x: plate.module * CGFloat(zone.leading), y: plate.module * CGFloat(zone.vertical)))
            #expect((plate.module * 2).rounded() == plate.module * 2, "a module is a whole number of pixels")
            #expect(plate.size.width <= width)
            // The biggest whole-pixel module that fits: one more pixel would not.
            let across = CGFloat(zone.leading + modules.columns + zone.trailing)
            let tallest = CGFloat(modules.rows + zone.vertical * 2)
            #expect((plate.module + 0.5) * across > width || (modules.rows > 1 && (plate.module + 0.5) * tallest > 1_000))
            if modules.rows > 1 {
                #expect(plate.size.height == plate.module * CGFloat(modules.rows + zone.vertical * 2))
            }
        }
    }

    @Test func eachFormatHasItsStandardsQuietZone() {
        #expect(BarcodeType.code128.quietZone == BarcodeQuietZone(leading: 10, trailing: 10, vertical: 0))
        #expect(BarcodeType.ean13.quietZone == BarcodeQuietZone(leading: 11, trailing: 7, vertical: 0))
        #expect(BarcodeType.ean8.quietZone == BarcodeQuietZone(leading: 7, trailing: 7, vertical: 0))
        #expect(BarcodeType.upce.quietZone == BarcodeQuietZone(leading: 9, trailing: 7, vertical: 0))
        #expect(BarcodeType.qrCode.quietZone == BarcodeQuietZone(leading: 4, trailing: 4, vertical: 4))
        #expect(BarcodeType.pdf417.quietZone == BarcodeQuietZone(leading: 2, trailing: 2, vertical: 2))
        #expect(BarcodeType.aztec.quietZone == BarcodeQuietZone(leading: 2, trailing: 2, vertical: 2))
    }

    /// The plate's corners never cut into the code: no rounder than its quiet zone is wide.
    @Test func cornersAreNoRounderThanTheQuietZoneIsWide() throws {
        let aztec = try #require(BarcodeModules(code: "JOESMARKET-4417", type: .aztec))
        let plate = try #require(
            BarcodePlate(modules: aztec, type: .aztec, fitting: CGSize(width: 180, height: 180), scale: 2, stripAspectRatio: 1.8)
        )
        #expect(plate.cornerRadius(upTo: 8, zone: BarcodeType.aztec.quietZone, isStrip: false) <= plate.module * 2)
        let qr = try #require(BarcodeModules(code: "https://serby.net", type: .qrCode))
        let qrPlate = try #require(
            BarcodePlate(modules: qr, type: .qrCode, fitting: CGSize(width: 180, height: 180), scale: 2, stripAspectRatio: 1.8)
        )
        #expect(qrPlate.cornerRadius(upTo: 8, zone: BarcodeType.qrCode.quietZone, isStrip: false) <= qrPlate.module * 4)
    }

    @Test func tooManyModulesForThePixelsHasNoPlate() throws {
        let modules = try #require(BarcodeModules(code: "LOCALROASTCOFFEE12345", type: .code39))
        #expect(BarcodePlate(modules: modules, type: .code39, fitting: CGSize(width: 60, height: 60), scale: 2, stripAspectRatio: 1.8) == nil)
    }

    /// For checking the drawings with the Mac's Vision, which the simulator lacks:
    /// writes each type's drawing, at two pixels a module on the card's blue,
    /// to WatchDrawings in the test's temporary folder.
    @Test func theDrawingsAreWrittenForCheckingByEye() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "WatchDrawings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (type, code) in WatchSampleCodes.all {
            let modules = try #require(BarcodeModules(code: code, type: type))
            let image = try #require(ModuleDrawing.image(modules, type: type, moduleSize: 2, surround: 24))
            let png = try #require(UIImage(cgImage: image).pngData())
            try png.write(to: folder.appending(path: "\(type.rawValue)|\(code).png"))
        }
    }
}
