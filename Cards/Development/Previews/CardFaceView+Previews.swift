import SwiftUI

#Preview("Barcode") {
    CardFaceView(card: .sample)
        .padding()
}

#Preview("QR code") {
    CardFaceView(card: .qr)
        .padding()
}

#Preview("With copy button") {
    CardFaceView(card: .sample, accessoryWidth: 44) {
        Image(systemName: "doc.on.doc")
            .foregroundStyle(CardPanel.secondaryInk)
            .frame(width: 44, height: 44)
    }
    .padding()
}
