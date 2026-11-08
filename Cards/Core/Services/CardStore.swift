import SwiftData

/// Where the cards live. SwiftData puts its default store in the first App Group
/// it finds in the entitlements, and Cards has one for the widget, so the store
/// is pinned to the app's own container, where every version before the widget
/// kept it. Moving it would strand existing cards in the old file.
public enum CardStore {
    public static let schema = Schema([CardItem.self])

    /// The iCloud container the cards sync through, as in the entitlements.
    public static let iCloudContainer = "iCloud.net.serby.Cards"
    /// The zone of the private database SwiftData mirrors the cards into, which
    /// Core Data's CloudKit mirroring names; deleting it deletes them from iCloud.
    public static let iCloudZone = "com.apple.coredata.cloudkit.zone"

    /// The store, syncing with iCloud only when `syncsWithICloud` (DATA-1). The
    /// same file either way, so turning sync off keeps every card on the device.
    /// An in-memory store (UI tests) never syncs: there is nothing to keep, and
    /// iOS 27.0 aborts on the first save when CloudKit mirrors one ("No eligible
    /// connection available").
    public static func configuration(inMemory: Bool, syncsWithICloud: Bool = true) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: .none,
            cloudKitDatabase: inMemory || !syncsWithICloud ? .none : .automatic
        )
    }
}
