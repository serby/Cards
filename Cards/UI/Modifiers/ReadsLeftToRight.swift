import SwiftUI

public extension View {
    /// Lays the view out left to right whatever the language, for text that is
    /// always written left to right: card codes, version numbers, JSON. In a
    /// right-to-left layout the bidirectional algorithm would otherwise reorder
    /// its runs, so a code such as "123-ABC 45" would read "45 ABC-123".
    func readsLeftToRight() -> some View {
        environment(\.layoutDirection, .leftToRight)
    }
}
