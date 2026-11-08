import SwiftUI

extension View {
    /// A text field row in the location picker's panel: leading icon, system
    /// fill, and room to grow with Dynamic Type.
    func pickerField(_ systemImage: String) -> some View {
        modifier(PickerField(systemImage: systemImage))
    }
}

private struct PickerField: ViewModifier {
    let systemImage: String
    /// The icon's column grows with the text, so at the largest sizes the
    /// grown icon keeps clear of the text beside it instead of running into it.
    @ScaledMetric(relativeTo: .body) private var iconWidth = 20.0
    /// One line of body text, which the icon is centred on, so it sits on the
    /// first line at every text size, the field empty or not.
    @ScaledMetric(relativeTo: .body) private var lineHeight = 22.0

    func body(content: Content) -> some View {
        // Top-aligned, with the icon a line tall, rather than on the first text
        // baseline: an empty multi-line field reports no baseline, which left
        // the icon a line above the prompt (PLACE-1).
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.secondaryText)
                .frame(width: iconWidth, height: lineHeight)
                .accessibilityHidden(true)
            content
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color(UIColor.tertiarySystemFill), in: .rect(cornerRadius: 12))
    }
}
