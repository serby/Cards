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

    func body(content: Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.secondaryText)
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            content
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color(UIColor.tertiarySystemFill), in: .rect(cornerRadius: 12))
    }
}
