import SwiftUI

public extension Binding where Value == String {
    /// For a text field with a vertical axis, which wraps long text at large
    /// text sizes rather than cutting it off with an ellipsis, but takes Return
    /// as a line break: drops the line break and calls `onReturn`, as a
    /// single-line field would. Pasted line breaks are dropped too.
    func singleLine(onReturn: @escaping @MainActor () -> Void = {}) -> Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                guard newValue.contains(where: \.isNewline) else {
                    wrappedValue = newValue
                    return
                }
                wrappedValue = newValue.filter { !$0.isNewline }
                MainActor.assumeIsolated(onReturn)
            }
        )
    }
}
