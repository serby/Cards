@testable import Cards
import Foundation
import SwiftData
import Testing

/// Importing an export chosen as a file (DATA-7) goes the way pasting its text
/// does (DATA-3, DATA-4). Files are read through a stand-in reader, except in
/// the one test of the live reader, which reads a temporary file.
@MainActor
struct ImportFileTests {
    private let export = #"[{"code": "111", "name": "Gym", "order": 0}, {"code": "222", "name": "Library", "order": 1}]"#
    private let chosen: Result<URL, any Error> = .success(URL(filePath: "/Imports/cards.json"))

    /// An empty in-memory store, or one holding `existing`.
    private func store(_ existing: [CardItem] = []) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CardItem.self, configurations: configuration)
        existing.forEach(container.mainContext.insert)
        try container.mainContext.save()
        return container
    }

    private func cards(in container: ModelContainer) throws -> [CardItem] {
        try container.mainContext.fetch(FetchDescriptor<CardItem>(sortBy: [SortDescriptor(\.order)]))
    }

    /// A file that holds `contents`.
    private func file(_ contents: String) -> FileReader {
        FileReader { _ in Data(contents.utf8) }
    }

    @Test func aFileImportsAsItsTextWould() throws {
        let pasted = try store()
        let chosenFile = try store()

        let pastedMessage = SettingsScreen.importText(export, existing: [], into: pasted.mainContext)
        let fileMessage = SettingsScreen.importFile(chosen, reader: file(export), existing: [], into: chosenFile.mainContext)

        #expect(fileMessage == "Imported 2 cards.")
        #expect(fileMessage == pastedMessage)
        #expect(try cards(in: chosenFile).map(\.code) == ["111", "222"])
        #expect(try cards(in: chosenFile).map(\.name) == cards(in: pasted).map(\.name))
    }

    @Test func aFileSkipsDuplicatesAsTextDoes() throws {
        let contents = #"[{"code": "111", "name": "Gym"}, {"code": "333", "name": "Pool"}, {"code": " 333 ", "name": "Pool again"}]"#
        // Each store gets its own card: a model belongs to one container, and
        // is unusable once that container has gone.
        let gym = CardItem(code: "111", name: "Gym", order: 0)
        let chosenFile = try store([gym])
        let pastedGym = CardItem(code: "111", name: "Gym", order: 0)
        let pasted = try store([pastedGym])

        let fileMessage = SettingsScreen.importFile(chosen, reader: file(contents), existing: [gym], into: chosenFile.mainContext)
        let pastedMessage = SettingsScreen.importText(contents, existing: [pastedGym], into: pasted.mainContext)

        #expect(fileMessage == "Imported 1 card. 1 was already in Card Barcodes. 1 was in the file more than once.")
        #expect(fileMessage == pastedMessage)
        #expect(try cards(in: chosenFile).map(\.code) == ["111", "333"])
        #expect(try cards(in: chosenFile).map(\.order) == [0, 1])
    }

    @Test(arguments: [
        "",
        "Not an export",
        #"{"code": "111", "name": "Gym"}"#,
        #"[{"name": "No code"}]"#,
        #"[{"code": "111", "name": "Gym", "timestamp": "yesterday"}]"#
    ])
    func aFileThatIsNotAnExportImportsNothing(contents: String) throws {
        let container = try store()
        let pasted = try store()

        let message = SettingsScreen.importFile(chosen, reader: file(contents), existing: [], into: container.mainContext)

        #expect(message == "Invalid JSON format")
        #expect(message == SettingsScreen.importText(contents, existing: [], into: pasted.mainContext))
        #expect(try cards(in: container).isEmpty)
    }

    @Test func aFileThatCannotBeReadImportsNothing() throws {
        let container = try store()
        let unreadable = FileReader { _ in throw CocoaError(.fileReadNoPermission) }

        #expect(SettingsScreen.importFile(chosen, reader: unreadable, existing: [], into: container.mainContext) == "Invalid JSON format")
        #expect(try cards(in: container).isEmpty)
    }

    @Test func aFileThatCouldNotBeChosenIsNeverRead() throws {
        let container = try store()
        let neverRead = FileReader { _ in
            Issue.record("Nothing was chosen, so nothing should be read")
            return Data()
        }

        let message = SettingsScreen.importFile(.failure(CocoaError(.fileReadUnknown)), reader: neverRead, existing: [], into: container.mainContext)

        #expect(message == "Invalid JSON format")
        #expect(try cards(in: container).isEmpty)
    }

    @Test func theLiveReaderReadsTheChosenFile() throws {
        let url = URL.temporaryDirectory.appending(path: "cards-\(UUID().uuidString).json")
        try Data(export.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try FileReader.live.read(url) == Data(export.utf8))
        #expect(throws: CocoaError.self) {
            try FileReader.live.read(url.deletingLastPathComponent().appending(path: "missing-\(UUID().uuidString).json"))
        }
    }
}
