@testable import Cards
import Foundation
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
}
