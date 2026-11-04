import SwiftUI

extension View {
    /// Draws a widget face at the medium size of a 6.1" iPhone, with the
    /// margins and background WidgetKit would give it.
    func widgetPreviewFrame(_ color: CardColor) -> some View {
        padding(16)
            .frame(width: 338, height: 158)
            .background(color.widgetFill, in: .rect(cornerRadius: 22))
            // Gives the panels' ContainerRelativeShape the widget's corners, as WidgetKit does.
            .containerShape(.rect(cornerRadius: 22))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
