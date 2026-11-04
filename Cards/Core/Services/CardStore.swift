import SwiftData

/// Where the cards live. SwiftData puts its default store in the first App Group
/// it finds in the entitlements, and Cards has one for the widget, so the store
/// is pinned to the app's own container, where every version before the widget
/// kept it. Moving it would strand existing cards in the old file.
public enum CardStore {
    public static let schema = Schema([CardItem.self])

    public static func configuration(inMemory: Bool) -> ModelConfiguration {
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, groupContainer: .none)
    }
}
