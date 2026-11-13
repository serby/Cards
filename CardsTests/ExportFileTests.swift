@testable import Cards
import Foundation
import SwiftData
import Testing

/// Exporting the cards as a file (DATA-2), and importing that file again
/// (DATA-7). Files are written to and read from a temporary folder of each
/// test's own, through the live reader and the writer the live one is made
/// from. Results are read in English, whatever language the tests run in.
@MainActor
struct ExportFileTests {
    private let english = Locale(identifier: "en_GB")
    /// Where the exports are made: GMT in November, an hour ahead in summer.
    private func london() throws -> TimeZone {
        try #require(TimeZone(identifier: "Europe/London"))
    }
    /// 9:41 on 13 November 2026 in London, in whole seconds, as ISO 8601 keeps dates.
    private let exportDay = Date(timeIntervalSince1970: 1_794_562_860)

    /// An empty in-memory store, or one holding `cards`.
    private func store(_ cards: [CardItem] = []) throws -> ModelContainer {
        let container = try ModelContainer(for: CardStore.schema, configurations: [CardStore.configuration(inMemory: true)])
        cards.forEach(container.mainContext.insert)
        try container.mainContext.save()
        return container
    }

    /// The cards in `container`, in list order, as Settings reads them.
    private func cards(in container: ModelContainer) throws -> [CardItem] {
        try container.mainContext.fetch(FetchDescriptor<CardItem>(sortBy: [SortDescriptor(\.order)]))
    }

    /// A folder of this test's own, which `body` writes in and reads from, removed afterwards.
    private func inTemporaryFolder<T>(_ body: (URL) throws -> T) throws -> T {
        let folder = URL.temporaryDirectory.appending(path: "ExportFileTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        return try body(folder)
    }

    /// Cards with every field filled in, dated in whole seconds so they come back exactly.
    private func everyKindOfCard() -> [CardItem] {
        let viewed = Date(timeIntervalSince1970: 1_794_500_000)
        return [
            CardItem(
                timestamp: Date(timeIntervalSince1970: 1_790_000_000),
                code: "5012345678900",
                name: "Joe's Market",
                barcodeType: .ean13,
                order: 0,
                color: .green,
                locations: [
                    CardLocation(
                        id: UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF") ?? UUID(),
                        name: "Joe's Market Notting Hill",
                        latitude: 51.5154,
                        longitude: -0.2050,
                        radius: 150
                    )
                ],
                notifiesOnArrival: false,
                icon: "cart.fill",
                lastViewed: viewed,
                notes: "Members' evening on Thursdays"
            ),
            CardItem(
                timestamp: Date(timeIntervalSince1970: 1_791_000_000),
                code: "LRC-2210",
                name: "Local Roast Coffee",
                barcodeType: .qrCode,
                order: 1,
                color: .custom(0x7A_4A_2B)
            ),
            CardItem(timestamp: Date(timeIntervalSince1970: 1_792_000_000), code: "88001234", name: "Ladbroke Library", order: 2)
        ]
    }

    // MARK: - The file's name

    /// The day is the one where the device is, not in GMT, where
    /// ISO8601FormatStyle would put it: late on 13 November in London is
    /// already the 14th in Tokyo, and early that day is still the 12th in Los
    /// Angeles; on a summer night in London, British Summer Time is a day
    /// ahead of GMT.
    @Test(arguments: [
        ("2026-11-13T09:41:00Z", "Europe/London", "Card Barcodes 2026-11-13.json"),
        ("2026-11-13T23:30:00Z", "Europe/London", "Card Barcodes 2026-11-13.json"),
        ("2026-11-13T23:30:00Z", "Asia/Tokyo", "Card Barcodes 2026-11-14.json"),
        ("2026-11-13T05:00:00Z", "America/Los_Angeles", "Card Barcodes 2026-11-12.json"),
        ("2026-07-01T23:30:00Z", "Europe/London", "Card Barcodes 2026-07-02.json"),
        ("2027-01-01T00:15:00Z", "Europe/London", "Card Barcodes 2027-01-01.json")
    ])
    func theFileIsNamedForTheDayWhereTheDeviceIs(instant: String, timeZone: String, name: String) throws {
        let date = try Date(instant, strategy: .iso8601)
        let zone = try #require(TimeZone(identifier: timeZone))

        #expect(CardExport.fileName(on: date, in: zone) == name)
    }

    // MARK: - What it holds

    /// The JSON is pretty-printed, with sorted keys and ISO 8601 dates.
    @Test func theFileHoldsTheCardsAsPrettyPrintedJSON() throws {
        let card = CardItem(timestamp: exportDay, code: "111", name: "Boulder Barn Climbing", order: 0)

        let json = try #require(String(bytes: CardExport.json([card]), encoding: .utf8))

        #expect(json.hasPrefix("[\n  {\n"))
        #expect(json.contains(#""timestamp" : "2026-11-13T09:41:00Z""#))
        let keys = ["code", "color", "locations", "name", "notifiesOnArrival", "order", "timestamp", "type"]
        let positions = try keys.map { key in try #require(json.range(of: "\"\(key)\" :")).lowerBound }
        #expect(positions == positions.sorted())
    }

    // MARK: - Export, then import

    /// DATA-2 and DATA-7: Export as JSON writes a file named for the day, and
    /// Choose File on another device, here an empty store, imports every card
    /// from it as it was. Exporting the imported cards gives the same file.
    @Test func anExportedFileImportsTheSameCardsOnAnotherDevice() throws {
        let original = try store(everyKindOfCard())
        let otherDevice = try store()

        try inTemporaryFolder { folder in
            let exported = try SettingsScreen.export(cards(in: original), on: exportDay, in: london(), writer: .folder(at: folder))
            guard case .file(let file) = exported else {
                Issue.record("Export as JSON shared \(String(describing: exported)), not a file")
                return
            }
            #expect(file.lastPathComponent == "Card Barcodes 2026-11-13.json")
            #expect(file.pathExtension == "json")

            let message = SettingsScreen.importFile(.success(file), reader: .live, existing: [], into: otherDevice.mainContext, locale: english)

            #expect(message == "Imported 3 cards.")
            let imported = try cards(in: otherDevice)
            #expect(imported.map(\.name) == ["Joe's Market", "Local Roast Coffee", "Ladbroke Library"])
            #expect(imported.first?.locations.first?.name == "Joe's Market Notting Hill")
            #expect(imported.first?.notes == "Members' evening on Thursdays")
            #expect(try CardExport.json(imported) == FileReader.live.read(file))
        }
    }

    /// Importing the file on the device it came from adds nothing, as every card is already there.
    @Test func anExportedFileAddsNothingWhereItsCardsAlreadyAre() throws {
        let device = try store(everyKindOfCard())

        try inTemporaryFolder { folder in
            let existing = try cards(in: device)
            guard case .file(let file) = try SettingsScreen.export(existing, on: exportDay, in: london(), writer: .folder(at: folder)) else {
                Issue.record("Export as JSON did not share a file")
                return
            }

            let message = SettingsScreen.importFile(.success(file), reader: .live, existing: existing, into: device.mainContext, locale: english)

            #expect(message == "No cards imported. 3 were already in Card Barcodes.")
            #expect(try cards(in: device).count == 3)
        }
    }

    /// DATA-7: an export saved to Files before 1.5 was kept as a text file,
    /// which Choose File now takes, and it imports as the JSON file would.
    @Test func anExportSavedAsTextBefore15Imports() throws {
        let otherDevice = try store()

        try inTemporaryFolder { folder in
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let text = folder.appending(path: "Text.txt")
            try CardExport.json(everyKindOfCard()).write(to: text)

            let message = SettingsScreen.importFile(.success(text), reader: .live, existing: [], into: otherDevice.mainContext, locale: english)

            #expect(message == "Imported 3 cards.")
        }
    }

    /// If the file cannot be written, the share sheet still gets the cards, as
    /// their text, as it did before 1.5.
    @Test func aFileThatCannotBeWrittenSharesTheTextInstead() throws {
        let cards = everyKindOfCard()
        let full = FileWriter { _, _ in throw CocoaError(.fileWriteOutOfSpace) }

        let exported = try SettingsScreen.export(cards, on: exportDay, in: london(), writer: full)

        let text = try #require(String(bytes: CardExport.json(cards), encoding: .utf8))
        #expect(exported == .text(text))
    }

    /// The live writer's folder keeps only the latest export, so a file a day does not pile up.
    @Test func theWritersFolderKeepsOnlyTheLatestExport() throws {
        try inTemporaryFolder { folder in
            let writer = FileWriter.folder(at: folder)

            _ = try writer.write(Data("[]".utf8), "Card Barcodes 2026-11-12.json")
            let latest = try writer.write(Data("[ ]".utf8), "Card Barcodes 2026-11-13.json")

            #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)) == ["Card Barcodes 2026-11-13.json"])
            #expect(try FileReader.live.read(latest) == Data("[ ]".utf8))
        }
    }
}

/// The copy iOS hands the app to open goes once it is imported, and nothing
/// else does (DATA-11).
struct HandedOverFileTests {
    @Test func onlyTheAppsOwnInboxCopiesCountAsHandedOver() {
        #expect(FileWriter.isHandedOver(URL.documentsDirectory.appending(path: "Inbox/Card Barcodes 2026-11-13.json")))
        #expect(FileWriter.isHandedOver(URL.temporaryDirectory.appending(path: "net.serby.Cards-Inbox/Card Barcodes 2026-11-13.json")))
        #expect(!FileWriter.isHandedOver(URL.documentsDirectory.appending(path: "Card Barcodes 2026-11-13.json")))
        #expect(!FileWriter.isHandedOver(URL(filePath: "/private/var/mobile/Library/Mobile Documents/Inbox/cards.json")))
    }
}
