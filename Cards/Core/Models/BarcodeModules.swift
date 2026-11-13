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

public extension BarcodeType {
    /// The light margin a scanner needs on each side of the code, in modules:
    /// ten for a strip of bars, four round a QR code, as its standard asks, and
    /// two round an Aztec code or a PDF417.
    var quietZone: Int {
        switch self {
        case .qrCode:
            4
        case .aztec, .pdf417:
            2
        case .code128, .code39, .ean8, .ean13, .code93, .upce:
            10
        }
    }
}
