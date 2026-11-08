@testable import Cards
import Foundation
import SwiftData
import Testing

struct CardStoreTests {
    /// Every version before the widget kept its store here. If SwiftData moved it
    /// to the App Group container, existing cards would vanish from the app.
    @Test func storeStaysInTheAppContainer() throws {
        let url = CardStore.configuration(inMemory: false).url
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        #expect(url == applicationSupport.appending(path: "default.store"))
        #expect(!url.path.contains("/AppGroup/"))
    }

    /// Turning iCloud Sync off opens the same file without iCloud, so every card
    /// stays on the device (DATA-8).
    @Test func syncOffKeepsTheSameStoreWithoutICloud() {
        let on = CardStore.configuration(inMemory: false)
        let off = CardStore.configuration(inMemory: false, syncsWithICloud: false)
        #expect(off.url == on.url)
        #expect(off.cloudKitContainerIdentifier == nil)
        #expect(on.cloudKitContainerIdentifier == CardStore.iCloudContainer)
    }

    /// A store that has synced with iCloud still saves once it is opened without
    /// it, and the other way round, keeping every card (DATA-8).
    @Test func aStoreKeepsSavingAsSyncIsTurnedOffAndOn() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "sync-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        func save(_ name: String, cloudKit: ModelConfiguration.CloudKitDatabase) throws -> Int {
            let container = try ModelContainer(for: CardStore.schema, configurations: [ModelConfiguration(url: url, cloudKitDatabase: cloudKit)])
            let context = ModelContext(container)
            context.insert(CardItem(code: name, name: name))
            try context.save()
            return try context.fetchCount(FetchDescriptor<CardItem>())
        }
        #expect(try save("Joe's Market", cloudKit: .automatic) == 1)
        #expect(try save("Local Roast Coffee", cloudKit: .none) == 2)
        #expect(try save("Green Leaf Pharmacy", cloudKit: .automatic) == 3)
    }
}
