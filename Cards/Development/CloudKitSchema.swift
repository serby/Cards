import CoreData
import OSLog
import SwiftData

/// Creates every CloudKit record type and field the model needs, in the
/// Development environment, so the schema can then be deployed to Production
/// in the CloudKit Console. SwiftData has no API for this, so it goes through
/// Core Data's NSPersistentCloudKitContainer, as Apple's SwiftData sync
/// documentation describes. Run it by launching a Debug build with
/// -initializeCloudKitSchema (see docs/DEVELOPMENT.md, "Releasing").
enum CloudKitSchema {
    static let containerIdentifier = "iCloud.net.serby.Cards"
    private static let log = Logger(subsystem: "net.serby.Cards", category: "CloudKitSchema")

    enum Failure: Error {
        case modelUnavailable
    }

    /// Must run before SwiftData opens the store at `storeURL`.
    static func initialize(storeURL: URL) throws {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: [CardItem.self]) else {
            throw Failure.modelUnavailable
        }
        let description = NSPersistentStoreDescription(url: storeURL)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: containerIdentifier
        )
        description.shouldAddStoreAsynchronously = false

        let container = NSPersistentCloudKitContainer(name: "Cards", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        // Called synchronously because shouldAddStoreAsynchronously is false.
        nonisolated(unsafe) var loadError: (any Error)?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        try container.initializeCloudKitSchema()
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
        log.notice("CloudKit schema initialised in the Development environment")
    }
}
