@testable import Cards
import CoreGraphics
import CoreLocation
import Foundation
import Testing
import UIKit
import Vision

/// A made-up code for each barcode type, valid for it (docs/LANGUAGE.md).
enum WatchSampleCodes {
    static let all: [(type: BarcodeType, code: String)] = [
        (.code128, "LRC-0042-7781"),
        (.code39, "JOE4417"),
        (.qrCode, "BOULDERBARN-10442"),
        (.ean8, "96385074"),
        (.ean13, "1234567890128"),
        (.code93, "LOCALROAST-93"),
        (.upce, "01234565"),
        (.aztec, "JOESMARKET-4417"),
        (.pdf417, "HONEYCOMB 77812")
    ]
}

/// Draws modules as the watch does (WATCH-3): on white with the type's quiet
/// zone, a strip's bars the full height, and square cells otherwise.
enum ModuleDrawing {
    static func image(_ modules: BarcodeModules, type: BarcodeType, moduleSize: Int) -> CGImage? {
        let quiet = type.quietZone
        let barHeight = modules.rows == 1 ? max(40, (modules.columns + quiet * 2) * moduleSize * 2 / 5) : 0
        let width = (modules.columns + quiet * 2) * moduleSize
        let height = modules.rows == 1 ? barHeight + quiet * moduleSize : (modules.rows + quiet * 2) * moduleSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.black.setFill()
            for row in 0..<modules.rows {
                for column in 0..<modules.columns where modules.isDark(column: column, row: row) {
                    let x = (quiet + column) * moduleSize
                    let rect = modules.rows == 1
                        ? CGRect(x: x, y: quiet * moduleSize / 2, width: moduleSize, height: barHeight)
                        : CGRect(x: x, y: (quiet + row) * moduleSize, width: moduleSize, height: moduleSize)
                    context.fill(rect)
                }
            }
        }.cgImage
    }
}

/// What the iPhone sends the Apple Watch (WATCH-1): each barcode as a grid of
/// modules read off the phone's own drawing, so the watch draws the same code.
struct BarcodeModulesTests {
    @Test(arguments: WatchSampleCodes.all)
    func everyTypeIsReadOffThePhonesDrawing(type: BarcodeType, code: String) throws {
        let modules = try #require(BarcodeModules(code: code, type: type))

        if type.isSquare {
            #expect(modules.columns == modules.rows)
        } else if type == .pdf417 {
            #expect(modules.rows > 1)
            #expect(modules.columns > modules.rows)
        } else {
            #expect(modules.rows == 1)
        }
        // The light margin is trimmed, so the code's own edges are dark.
        #expect(modules.dark.contains { $0.first == true })
        #expect(modules.dark.contains { $0.last == true })
        #expect(modules.dark.first?.contains(true) == true)
        #expect(modules.dark.last?.contains(true) == true)
    }

    /// The standards fix these: 95 modules for EAN-13, 67 for EAN-8, 51 for
    /// UPC-E, and 21 a side for a QR code this short.
    @Test(arguments: [(BarcodeType.ean13, "1234567890128", 95), (.ean8, "96385074", 67), (.upce, "01234565", 51)])
    func aStripHasTheModulesItsStandardSays(type: BarcodeType, code: String, columns: Int) throws {
        let modules = try #require(BarcodeModules(code: code, type: type))
        #expect(modules.columns == columns)
        #expect(Array(modules.dark[0].prefix(3)) == [true, false, true])
    }

    @Test func aShortQRCodeIs21ModulesASide() throws {
        let modules = try #require(BarcodeModules(code: "BOULDER", type: .qrCode))
        #expect((modules.columns, modules.rows) == (21, 21))
        // The finder pattern in the top left: seven dark, then a light module.
        #expect(Array(modules.dark[0].prefix(8)) == [true, true, true, true, true, true, true, false])
    }

    /// The phone's own barcode, drawn larger by `BarcodeImage.make`, has the
    /// very modules the watch is sent, in the same places.
    @Test(arguments: WatchSampleCodes.all)
    func theModulesMatchThePhonesBarcodeAtAnySize(type: BarcodeType, code: String) throws {
        let natural = try #require(BarcodeImage.unscaled(code, type: type))
        let size = CGSize(width: natural.width * 4, height: natural.height * 4)
        let drawn = try #require(BarcodeImage.make(code, type: type, size: size)?.cgImage)
        try #require(drawn.width % natural.width == 0)

        let read = BarcodeModules(darkPixelsOf: drawn, moduleSize: drawn.width / natural.width)

        #expect(read == BarcodeModules(code: code, type: type))
    }

    /// Drawn as the watch draws them and read again, the modules come back
    /// unchanged at any size: nothing is lost or moved on the way.
    @Test(arguments: WatchSampleCodes.all)
    func modulesSurviveBeingDrawnAndReadAgain(type: BarcodeType, code: String) throws {
        let modules = try #require(BarcodeModules(code: code, type: type))
        for moduleSize in [1, 3, 7] {
            let image = try #require(ModuleDrawing.image(modules, type: type, moduleSize: moduleSize))
            #expect(BarcodeModules(darkPixelsOf: image, moduleSize: moduleSize) == modules, "\(moduleSize) pixels a module")
        }
    }

    @Test func aCodeThatCannotBeDrawnHasNoModules() {
        #expect(BarcodeModules(code: "50123456789012", type: .ean13) == nil)
        #expect(BarcodeModules(code: "", type: .code128) == nil)
        #expect(BarcodeModules(code: "lower case", type: .upce) == nil)
    }

    @Test func aGridIsPackedEightModulesToAByteFromTheTopLeft() throws {
        let modules = try #require(BarcodeModules(dark: [[true, false, true], [false, true, true], [true, true, false]]))

        #expect(modules.bits == Data([0b1010_1111, 0b0000_0000]))
        #expect(modules.isDark(column: 2, row: 1))
        #expect(!modules.isDark(column: 2, row: 2))
        #expect(modules.dark == [[true, false, true], [false, true, true], [true, true, false]])
    }

    @Test func aGridThatDoesNotAddUpIsRefused() {
        #expect(BarcodeModules(columns: 3, rows: 3, bits: Data([0xFF])) == nil)
        #expect(BarcodeModules(columns: 0, rows: 1, bits: Data()) == nil)
        #expect(BarcodeModules(dark: [[true], [true, false]]) == nil)
        #expect(BarcodeModules(dark: []) == nil)

        let json = Data(#"{"columns":3,"rows":3,"bits":"/w=="}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(BarcodeModules.self, from: json) }
    }
}

/// Vision cannot make its barcode detector in the simulator (see
/// `VisionBarcodeDetector`), so this runs on a device: the modules, drawn as
/// the watch draws them, scan as the code they came from.
@Suite(.enabled(if: VisionBarcodeDetector.isAvailable, "Vision cannot make its barcode detector in the simulator"))
struct BarcodeModulesVisionTests {
    @Test(arguments: WatchSampleCodes.all)
    func theWatchesDrawingScans(type: BarcodeType, code: String) throws {
        let modules = try #require(BarcodeModules(code: code, type: type))
        let image = try #require(ModuleDrawing.image(modules, type: type, moduleSize: 4))
        let request = VNDetectBarcodesRequest()

        try VNImageRequestHandler(cgImage: image).perform([request])

        let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
        #expect(payloads.contains(code), "found \(payloads)")
    }
}

struct WatchCardTests {
    private let joesMarketNottingHill = CardLocation(name: "Joe's Market Notting Hill", latitude: 51.5090, longitude: -0.1960, radius: 150)
    private let joesMarketKensington = CardLocation(name: "Joe's Market Kensington", latitude: 51.4990, longitude: -0.1990, radius: 200)
    private let localRoastNottingHill = CardLocation(name: "Local Roast Notting Hill", latitude: 51.5093, longitude: -0.1966, radius: 150)
    private let boulderBarn = CardLocation(name: "Boulder Barn", latitude: 51.5203, longitude: -0.2094, radius: 150)
    /// Notting Hill Gate, inside Joe's Market Notting Hill and Local Roast Notting Hill.
    private let nottingHillGate = CLLocation(latitude: 51.5091, longitude: -0.1963)
    private let atBoulderBarn = CLLocation(latitude: 51.5204, longitude: -0.2094)
    private let wembley = CLLocation(latitude: 51.5560, longitude: -0.2796)

    private func card(_ name: String, _ locations: [CardLocation] = [], type: BarcodeType = .code128) -> WatchCard {
        WatchCard(
            code: name.lowercased(),
            name: name,
            barcodeType: type,
            color: .blue,
            icon: "cart.fill",
            locations: locations,
            modules: BarcodeModules(dark: [[true, false, true]])
        )
    }

    // MARK: What is sent

    @Test func aWatchCardCopiesWhatTheWatchShowsAndLeavesTheNotes() {
        let item = CardItem(
            code: "1234567890128",
            name: "Local Roast Coffee",
            barcodeType: .ean13,
            color: .red,
            locations: [localRoastNottingHill],
            icon: "cup.and.saucer.fill",
            notes: "Every tenth coffee is free."
        )

        let card = WatchCard(item)

        #expect(card == WatchCard(
            code: "1234567890128",
            name: "Local Roast Coffee",
            barcodeType: .ean13,
            color: .red,
            icon: "cup.and.saucer.fill",
            locations: [localRoastNottingHill],
            modules: BarcodeModules(code: "1234567890128", type: .ean13)
        ))
        #expect(card.modules?.columns == 95)
    }

    @Test func aCardWhoseCodeCannotBeDrawnGoesWithoutModules() {
        let item = CardItem(code: "50123456789012", name: "Ladbroke Library", barcodeType: .ean13, color: .orange)
        #expect(WatchCard(item).modules == nil)
    }

    @Test func aSnapshotRoundTripsAsItTravels() throws {
        let snapshot = WatchSnapshot(
            cards: [
                card("Joe's Market", [joesMarketNottingHill]),
                card("Honeycomb Rewards"),
                WatchCard(code: "x", name: "Ladbroke Library", barcodeType: .ean13, color: .custom(0x123456), modules: nil)
            ],
            distanceUnits: .miles
        )

        let encoded = try snapshot.encoded()

        #expect(try WatchSnapshot(encoded: encoded) == snapshot)
        // The same cards make the same bytes, so unchanged cards are not sent again.
        #expect(try snapshot.encoded() == encoded)
    }

    /// A watch app older than the phone's, or the other way round, still
    /// reads the cards: what it does not know falls back, what is missing is none.
    @Test func aSnapshotFromAnotherVersionIsReadTolerantly() throws {
        let cardJSON = #"{"code":"482019375610284","name":"Joe's Market","barcodeType":"Code 11","color":"ultraviolet"}"#
        let json = Data(#"{"cards":[\#(cardJSON)],"distanceUnits":"furlongs"}"#.utf8)

        let snapshot = try JSONDecoder().decode(WatchSnapshot.self, from: json)

        #expect(snapshot.distanceUnits == .automatic)
        #expect(snapshot.cards == [WatchCard(code: "482019375610284", name: "Joe's Market", barcodeType: .code128, color: .standard, modules: nil)])
    }

    @Test func dataThatIsNotASnapshotIsRefused() {
        #expect(throws: (any Error).self) { try WatchSnapshot(encoded: Data("Joe's Market".utf8)) }
    }

    /// The application context takes about 64 KB, and a snapshot larger than
    /// `contextLimit` goes as a file, so ordinary card collections go the
    /// quick way: a hundred cards with long codes and places, QR codes among them.
    @Test func aHundredCardsFitTheApplicationContext() throws {
        let cards = (0..<100).map { index in
            let type: BarcodeType = index.isMultiple(of: 10) ? .qrCode : .code128
            let code = "\(4_006_381_333_931 + index * 7)-\(index)"
            return WatchCard(
                code: code,
                name: "Joe's Market \(index)",
                barcodeType: type,
                color: .blue,
                icon: "cart.fill",
                locations: [joesMarketNottingHill, joesMarketKensington],
                modules: BarcodeModules(code: code, type: type)
            )
        }

        let size = try WatchSnapshot(cards: cards, distanceUnits: .automatic).encoded().count

        #expect(size < WatchSnapshot.contextLimit, "\(size) bytes")
    }

    // MARK: The card for where you are

    @Test func theCardForWhereYouAreIsOneWhosePlaceYouAreInside() {
        let cards = [
            card("Honeycomb Rewards"),
            card("Boulder Barn Climbing", [boulderBarn]),
            card("Joe's Market", [joesMarketKensington, joesMarketNottingHill])
        ]

        #expect(cards.arrival(at: atBoulderBarn) == WatchArrival(code: "boulder barn climbing", placeID: boulderBarn.id))
        #expect(cards.arrival(at: nottingHillGate) == WatchArrival(code: "joe's market", placeID: joesMarketNottingHill.id))
        #expect(cards.arrival(at: wembley) == nil)
        #expect(cards.arrival(at: nil) == nil)
    }

    /// Inside two places, the one whose middle is nearer, as the phone's
    /// "Here" decides; on a tie, the card higher in the list.
    @Test func insideSeveralPlacesTheNearestMiddleWins() {
        let localRoast = card("Local Roast Coffee", [localRoastNottingHill])
        let joesMarket = card("Joe's Market", [joesMarketNottingHill])

        #expect([localRoast, joesMarket].arrival(at: nottingHillGate)?.code == "joe's market")
        let twin = WatchCard(
            code: "twin",
            name: "Joe's Market Twin",
            barcodeType: .code128,
            color: .blue,
            locations: [joesMarketNottingHill],
            modules: nil
        )
        #expect([twin, joesMarket].arrival(at: nottingHillGate)?.code == "twin")
        #expect([joesMarket, twin].arrival(at: nottingHillGate)?.code == "joe's market")
    }

    /// Once per arrival: going back to the list leaves it showing until you
    /// have been seen outside the place.
    @Test func theWatchOpensTheCardOncePerArrival() {
        let cards = [card("Boulder Barn Climbing", [boulderBarn]), card("Joe's Market", [joesMarketNottingHill])]
        var arrivals = WatchArrivals()

        #expect(arrivals.cardToOpen(in: cards, at: atBoulderBarn) == "boulder barn climbing")
        #expect(arrivals.cardToOpen(in: cards, at: atBoulderBarn) == nil)
        #expect(arrivals.cardToOpen(in: cards, at: nil) == nil)
        #expect(arrivals.cardToOpen(in: cards, at: atBoulderBarn) == nil)
        #expect(arrivals.cardToOpen(in: cards, at: nottingHillGate) == "joe's market")
        #expect(arrivals.cardToOpen(in: cards, at: wembley) == nil)
        #expect(arrivals.current == nil)
        #expect(arrivals.cardToOpen(in: cards, at: nottingHillGate) == "joe's market")
    }

    @Test func withoutAFixTheWatchOpensNothing() {
        var arrivals = WatchArrivals()
        #expect(arrivals.cardToOpen(in: [card("Boulder Barn Climbing", [boulderBarn])], at: nil) == nil)
        #expect(arrivals.current == nil)
    }
}

/// The watch keeps the arrival a card was opened for, so a relaunch at the
/// same place leaves the list as you chose (WATCH-4).
struct WatchArrivalStorageTests {
    @Test func anArrivalRoundTripsThroughWhatTheWatchKeeps() throws {
        let arrival = WatchArrival(code: "https://serby.net/a b", placeID: UUID())
        #expect(WatchArrival(stored: arrival.stored) == arrival)
    }

    @Test(arguments: ["", "not-a-uuid code", "\(UUID().uuidString) ", "\(UUID().uuidString)"])
    func anythingElseIsNoArrival(_ stored: String) {
        #expect(WatchArrival(stored: stored) == nil)
    }
}
