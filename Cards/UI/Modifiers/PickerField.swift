import SwiftUI

extension View {
    /// A text field row in the location picker's panel: leading icon, system
    /// fill, and room to grow with Dynamic Type.
    func pickerField(_ systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            self
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color(UIColor.tertiarySystemFill), in: .rect(cornerRadius: 12))
    }
}
