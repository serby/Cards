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

    @ViewBuilder
    func tabBarMinimizeBehaviorIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollUp)
        } else {
            self
        }
    }
}
