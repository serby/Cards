import SwiftUI

/// Gives a story a namespace of its own, for a view that takes one, such as
/// the zoom sources of the Cards tab (CARD-4).
public struct WithNamespace<Content: View>: View {
    @Namespace private var namespace
    private let content: @MainActor (Namespace.ID) -> Content

    public init(@ViewBuilder content: @escaping @MainActor (Namespace.ID) -> Content) {
        self.content = content
    }

    public var body: some View {
        content(namespace)
    }
}
