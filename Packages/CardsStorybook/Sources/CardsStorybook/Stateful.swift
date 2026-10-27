import SwiftUI

/// Supplies a `Binding` to a view that needs one, for stories where the value
/// is local to the story rather than driven by a knob.
@MainActor
public struct Stateful<Value, Content: View>: View {
    @State private var value: Value
    private let content: @MainActor (Binding<Value>) -> Content

    public init(
        _ initial: Value,
        @ViewBuilder content: @escaping @MainActor (Binding<Value>) -> Content
    ) {
        _value = State(initialValue: initial)
        self.content = content
    }

    public var body: some View {
        content($value)
    }
}
