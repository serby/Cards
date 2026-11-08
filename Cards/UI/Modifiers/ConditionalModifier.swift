import SwiftUI

public extension View {
    @ViewBuilder
    func conditionalModifier<Content: View>(@ViewBuilder transform: (Self) -> Content) -> some View {
        transform(self)
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
