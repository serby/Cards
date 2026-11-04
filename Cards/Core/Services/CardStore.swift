import SwiftData

/// Where the cards live. SwiftData puts its default store in the first App Group
/// it finds in the entitlements, and Cards has one for the widget, so the store
/// is pinned to the app's own container, where every version before the widget
/// kept it. Moving it would strand existing cards in the old file.
public enum CardStore {
    public static let schema = Schema([CardItem.self])

    /// An in-memory store (UI tests) never syncs: there is nothing to keep, and
    /// iOS 27.0 aborts on the first save when CloudKit mirrors one ("No eligible
    /// connection available").
    public static func configuration(inMemory: Bool) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: .none,
            cloudKitDatabase: inMemory ? .none : .automatic
        )
    }
}
