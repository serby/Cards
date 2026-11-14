import CoreGraphics
import Foundation

/// A barcode as the grid of modules it is made of, each dark or light, one bit
/// apiece: how the iPhone hands a code to the Apple Watch, which has no Core
/// Image to draw one with (WATCH-1). The iPhone reads the grid off the drawing
/// `BarcodeImage` makes (`BarcodeModules(code:type:)`), so the watch draws the
/// very bars and squares the phone does, sharp at any size.
///
/// A strip barcode is a single row, as its bars run the code's full height. A
/// QR code, an Aztec code and a PDF417 have a row for each row of modules.
public struct BarcodeModules: Hashable, Sendable {
    public let columns: Int
    public let rows: Int
    /// Row by row from the top left, eight modules to a byte with the first in
    /// the high bit, and 1 for dark.
    public let bits: Data

    /// Nil unless `bits` holds exactly `columns` times `rows` modules.
    public init?(columns: Int, rows: Int, bits: Data) {
        guard columns > 0, rows > 0, bits.count == Self.byteCount(columns * rows) else { return nil }
        self.columns = columns
        self.rows = rows
        self.bits = bits
    }

    /// The grid `dark` describes, row by row, true for dark. Nil when it is
    /// empty or its rows differ in length.
    public init?(dark: [[Bool]]) {
        guard let width = dark.first?.count, width > 0, dark.allSatisfy({ $0.count == width }) else { return nil }
        var bytes = [UInt8](repeating: 0, count: Self.byteCount(width * dark.count))
        for (index, isDark) in dark.joined().enumerated() where isDark {
            bytes[index / 8] |= 0x80 >> UInt8(index % 8)
        }
        self.init(columns: width, rows: dark.count, bits: Data(bytes))
    }

    /// Whether the module at `column` (from the left) and `row` (from the top) is dark.
    public func isDark(column: Int, row: Int) -> Bool {
        let index = row * columns + column
        return bits[bits.startIndex + index / 8] & (0x80 >> UInt8(index % 8)) != 0
    }

    /// The grid as rows of true for dark, as `init(dark:)` takes it.
    public var dark: [[Bool]] {
        (0..<rows).map { row in (0..<columns).map { isDark(column: $0, row: row) } }
    }

    private static func byteCount(_ modules: Int) -> Int {
        (modules + 7) / 8
    }
}

/// Encoded as its columns, rows and bits, the bits in base64, and checked as it
/// is read, so a grid that does not add up is never drawn.
extension BarcodeModules: Codable {
    private enum CodingKeys: String, CodingKey {
        case columns
        case rows
        case bits
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let columns = try container.decode(Int.self, forKey: .columns)
        let rows = try container.decode(Int.self, forKey: .rows)
        let bits = try container.decode(Data.self, forKey: .bits)
        guard let modules = Self(columns: columns, rows: rows, bits: bits) else {
            throw DecodingError.dataCorruptedError(
                forKey: .bits,
                in: container,
                debugDescription: "\(bits.count) bytes for \(columns) by \(rows) modules"
            )
        }
        self = modules
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(columns, forKey: .columns)
        try container.encode(rows, forKey: .rows)
        try container.encode(bits, forKey: .bits)
    }
}

/// The light margin a scanner needs round a code, in modules, as each
/// format's standard sets it, and no more (WATCH-3). A strip barcode needs it
/// only at its two ends, as its bars run its full height.
public struct BarcodeQuietZone: Hashable, Sendable {
    /// Before the first module, and after the last.
    public let leading: Int
    public let trailing: Int
    /// Above and below, for a code of rows; none for a strip.
    public let vertical: Int

    public init(leading: Int, trailing: Int, vertical: Int) {
        self.leading = leading
        self.trailing = trailing
        self.vertical = vertical
    }
}

public extension BarcodeType {
    /// The quiet zone its standard requires: ten modules at each end of a Code
    /// 128, a Code 39 or a Code 93; eleven before and seven after an EAN-13,
    /// seven each side of an EAN-8, nine before and seven after a UPC-E; four
    /// all round a QR code and two round a PDF417. An Aztec code's standard
    /// asks for none, as its finder is at its middle, but on a card's colour
    /// Vision reads none of it without a light margin and all of it with one
    /// module, so it has two, a module to spare for a till's scanner.
    var quietZone: BarcodeQuietZone {
        switch self {
        case .code128, .code39, .code93:
            BarcodeQuietZone(leading: 10, trailing: 10, vertical: 0)
        case .ean13:
            BarcodeQuietZone(leading: 11, trailing: 7, vertical: 0)
        case .ean8:
            BarcodeQuietZone(leading: 7, trailing: 7, vertical: 0)
        case .upce:
            BarcodeQuietZone(leading: 9, trailing: 7, vertical: 0)
        case .qrCode:
            BarcodeQuietZone(leading: 4, trailing: 4, vertical: 4)
        case .pdf417:
            BarcodeQuietZone(leading: 2, trailing: 2, vertical: 2)
        case .aztec:
            BarcodeQuietZone(leading: 2, trailing: 2, vertical: 2)
        }
    }
}

/// Where a code goes on its white plate, in points, for a space it must fit
/// (WATCH-3): each module a whole number of the screen's pixels, so every bar
/// is the same width with sharp edges, and the plate exactly the code and its
/// quiet zone, with no more white. Nil when a module would be under a pixel,
/// as it would blur to grey that no scanner reads.
public struct BarcodePlate: Equatable, Sendable {
    /// The plate's size: the code and its quiet zone.
    public let size: CGSize
    /// One module's width, and a 2D code's module height.
    public let module: CGFloat
    /// The code's top-left corner on the plate.
    public let origin: CGPoint
    /// How tall each row of modules is: a strip's bars run the plate's height.
    public let rowHeight: CGFloat

    /// The plate for `modules` of `type` in `space`, at `scale` pixels a
    /// point. A strip's plate is `stripAspectRatio` times as wide as it is high.
    public init?(modules: BarcodeModules, type: BarcodeType, fitting space: CGSize, scale: CGFloat, stripAspectRatio: CGFloat) {
        let zone = type.quietZone
        let isStrip = modules.rows == 1
        let across = CGFloat(zone.leading + modules.columns + zone.trailing)
        let down = CGFloat(modules.rows + zone.vertical * 2)
        var pixels = (space.width * scale / across).rounded(.down)
        if !isStrip {
            pixels = min(pixels, (space.height * scale / down).rounded(.down))
        }
        guard pixels >= 1, scale > 0 else { return nil }
        module = pixels / scale
        let width = module * across
        let height = isStrip ? ((width / stripAspectRatio) * scale).rounded() / scale : module * down
        size = CGSize(width: width, height: height)
        origin = CGPoint(x: module * CGFloat(zone.leading), y: module * CGFloat(zone.vertical))
        rowHeight = isStrip ? height : module
    }

    /// The plate's corners, round but never into the code: no rounder than
    /// the quiet zone is wide, so an Aztec code's plate is square.
    public func cornerRadius(upTo maximum: CGFloat, zone: BarcodeQuietZone, isStrip: Bool) -> CGFloat {
        let sides = CGFloat(min(zone.leading, zone.trailing)) * module
        return min(maximum, isStrip ? sides : min(sides, CGFloat(zone.vertical) * module))
    }
}
