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
    static let containerIdentifier = CardStore.iCloudContainer
    private static let log = Logger(subsystem: "net.serby.Cards", category: "CloudKitSchema")

    enum Failure: Error {
        case modelUnavailable
    }

    /// Uses a throwaway store, never the real one: the real store's sync
    /// metadata belongs to whichever environment it last synced with, and
    /// reusing it makes CloudKit report "Zone Not Found".
    static func initialize() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "CloudKitSchema-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Schema.store")

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
