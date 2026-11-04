import SwiftUI

public extension Binding where Value == String {
    /// For a text field with a vertical axis, which wraps long text at large
    /// text sizes rather than cutting it off with an ellipsis, but takes Return
    /// as a line break: drops the line break and calls `onReturn`, as a
    /// single-line field would. Pasted line breaks are dropped too.
    ///
    /// The line break is stored first and dropped a moment later, never in the
    /// same update. Dropped at once, Return wrote back the value the field
    /// already had, so SwiftUI saw no change and never laid the field out
    /// again, and the text view stayed on the empty line the Return had added:
    /// in French the card form's name field drew blank, though it kept the name.
    func singleLine(onReturn: @escaping @MainActor () -> Void = {}) -> Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                wrappedValue = newValue
                guard newValue.contains(where: \.isNewline) else { return }
                Task { @MainActor in
                    wrappedValue = wrappedValue.filter { !$0.isNewline }
                    onReturn()
                }
            }
        )
    }
}
