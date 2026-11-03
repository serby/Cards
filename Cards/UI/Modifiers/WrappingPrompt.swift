import SwiftUI

public extension View {
    /// Shows `prompt` behind an empty text field, wrapping onto as many lines
    /// as it needs, in the app's readable secondary text. A field's own prompt
    /// stays on one line even with a vertical axis, so at large text sizes and
    /// in longer languages it was cut off ("Enter na…", "Postco…"), and where
    /// the prompt is a field's only visible label that hid what the field is
    /// for. Give the field an empty prompt of its own. VoiceOver reads the
    /// field's label, so this prompt is hidden from it; a tap on its lines
    /// below the field's first one calls `onTap`, which should focus the field.
    func wrappingPrompt(
        _ prompt: Text,
        isShown: Bool,
        alignment: TextAlignment = .leading,
        onTap: @escaping () -> Void
    ) -> some View {
        modifier(WrappingPrompt(prompt: prompt, isShown: isShown, alignment: alignment, onTap: onTap))
    }
}

private struct WrappingPrompt: ViewModifier {
    let prompt: Text
    let isShown: Bool
    let alignment: TextAlignment
    let onTap: () -> Void

    private var frameAlignment: Alignment {
        if alignment == .trailing { return .topTrailing }
        return alignment == .center ? .top : .topLeading
    }

    func body(content: Content) -> some View {
        // A stack, not an overlay, so a prompt longer than the empty field
        // makes the row taller instead of spilling out of it.
        ZStack(alignment: frameAlignment) {
            if isShown {
                prompt
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(alignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .contentShape(.rect)
                    .onTapGesture(perform: onTap)
                    .accessibilityHidden(true)
                    // XCUITest and its accessibility audit still see it, and
                    // the audit tells it apart by this.
                    .accessibilityIdentifier("wrappingPrompt")
            }
            content
        }
    }
}
