import SwiftUI

#Preview("Nearby") {
    CardWidgetView(card: .sample).widgetPreviewFrame(.blue)
}

#Preview("QR code") {
    CardWidgetView(card: .qr).widgetPreviewFrame(.graphite)
}

#Preview("No cards") {
    CardWidgetView(card: nil).widgetPreviewFrame(.standard)
}
