import SwiftUI

#Preview {
    BarcodeView(barcodeString: "123456", barcodeType: .code128)
    BarcodeView(barcodeString: "", barcodeType: .ean13)
}
