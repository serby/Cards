/// What the Apple Watch needs from a card, with its barcode drawn here, as the
/// watch cannot draw one (WATCH-1). In Features because it draws with the UI's
/// `BarcodeImage`, and the watch shares `WatchCard` but neither the store nor
/// the drawing.
public extension WatchCard {
    init(_ card: CardItem) {
        let type = card.getBarcodeType()
        self.init(
            code: card.code,
            name: card.name,
            barcodeType: type,
            color: card.getColor(),
            icon: card.icon,
            locations: card.locations,
            modules: BarcodeModules(code: card.code, type: type)
        )
    }
}
