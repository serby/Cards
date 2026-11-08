import CloudKit
import SwiftUI

/// The copy of the cards in the person's iCloud account, which SwiftData keeps
/// while iCloud Sync is on (DATA-1), injected so nothing but the live value
/// reaches CloudKit.
public struct ICloudCards: Sendable {
    /// Deletes every card in iCloud (DATA-9). Nothing there to delete is not an
    /// error. The cards on the device are untouched.
    public var deleteAll: @Sendable () async throws -> Void

    public init(deleteAll: @escaping @Sendable () async throws -> Void) {
        self.deleteAll = deleteAll
    }
}

public extension ICloudCards {
    /// The private database of the app's iCloud container. SwiftData mirrors
    /// every card into one zone, so deleting the zone deletes them all.
    static let live = Self(deleteAll: {
        let database = CKContainer(identifier: CardStore.iCloudContainer).privateCloudDatabase
        let zone = CKRecordZone.ID(zoneName: CardStore.iCloudZone, ownerName: CKCurrentUserDefaultName)
        do {
            _ = try await database.deleteRecordZone(withID: zone)
        } catch let error as CKError where isNothingToDelete(error) {
            return
        }
    })

    /// Whether `error` only says there was nothing in iCloud to delete.
    static func isNothingToDelete(_ error: CKError) -> Bool {
        [.zoneNotFound, .userDeletedZone, .unknownItem].contains(error.code)
    }
}

private struct ICloudCardsKey: EnvironmentKey {
    static let defaultValue = ICloudCards.live
}

public extension EnvironmentValues {
    var iCloudCards: ICloudCards {
        get { self[ICloudCardsKey.self] }
        set { self[ICloudCardsKey.self] = newValue }
    }
}
