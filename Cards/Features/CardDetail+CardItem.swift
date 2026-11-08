import CoreLocation

extension CardDetail {
    /// What a screen shows of `item`, with the distance from `location` when known.
    /// The card screen and the card for where you are both draw it, so they agree.
    init(_ item: CardItem, near location: CLLocation?) {
        self.init(
            id: item.code,
            name: item.name,
            code: item.code,
            barcodeType: item.getBarcodeType(),
            timestamp: item.timestamp,
            color: item.getColor(),
            places: CardPlaces(item.locations, near: location),
            proximity: item.locations.proximity(to: location),
            icon: item.icon,
            notes: item.notes
        )
    }
}
