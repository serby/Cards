import Foundation

/// Exporting the cards (DATA-2): the file's name and what it holds. Writing
/// the file is `FileWriter`'s job; importing it again is `CardImport`'s.
public enum CardExport {
    /// The app's name, which starts the file's name. It is the same in every
    /// language, so the file's name is never translated.
    static let appName = "Card Barcodes"

    /// The export's file name, as "Card Barcodes 2026-11-13.json": the day
    /// `date` falls on in `timeZone`, as year, month and day, which sorts by
    /// date and reads the same in every language and calendar.
    public static func fileName(on date: Date, in timeZone: TimeZone) -> String {
        // ISO8601FormatStyle is in GMT unless it is given a time zone.
        let day = date.formatted(Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day())
        return "\(appName) \(day).json"
    }

    /// The export of `cards`, in the order given: a JSON array of cards,
    /// pretty-printed with sorted keys and ISO 8601 dates, as an import reads it.
    public static func json(_ cards: [CardItem]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(cards.map(CardItemDTO.init(from:)))
    }
}
