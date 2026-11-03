import SwiftData

/// The cards the App Store screenshots show. The screenshot UI test launches
/// the app with -screenshotSeed, and DevelopmentHooks inserts these.
enum ScreenshotSeed {
    @MainActor
    static func insert(into context: ModelContext) throws {
        let cards = [
            CardItem(code: "634004024987531", name: "Tesco Clubcard", barcodeType: .ean13, order: 0, color: .blue),
            CardItem(code: "9780201379624", name: "Boots Advantage", barcodeType: .ean13, order: 1, color: .indigo),
            CardItem(code: "1234567890128", name: "Costa Coffee", barcodeType: .ean13, order: 2, color: .red),
            CardItem(code: "9988776655443", name: "Nectar", barcodeType: .code128, order: 3, color: .purple),
            CardItem(code: "5012345678900", name: "Sainsbury's Nectar", barcodeType: .ean13, order: 4, color: .orange),
            CardItem(code: "7350053850019", name: "IKEA Family", barcodeType: .code128, order: 5, color: .yellow)
        ]
        cards.forEach(context.insert)
        try context.save()
    }
}
