extension CardDraft {
    /// The form's fields for `item`, as the edit form opens on them.
    init(_ item: CardItem) {
        self.init(
            name: item.name,
            code: item.code,
            barcodeType: item.getBarcodeType(),
            color: item.getColor(),
            locations: item.locations,
            notifiesOnArrival: item.notifiesOnArrival,
            icon: item.icon,
            notes: item.notes ?? ""
        )
    }
}

extension CardItem {
    /// Writes every field of `draft` to the card, as saving the form does, with
    /// the name and code trimmed (CARD-3) and blank notes saved as none (CARD-14).
    func apply(_ draft: CardDraft) {
        name = draft.trimmedName
        code = draft.trimmedCode
        type = draft.barcodeType.rawValue
        color = draft.color.rawValue
        locations = draft.locations
        notifiesOnArrival = draft.notifiesOnArrival
        icon = draft.icon
        notes = CardNotes.kept(draft.notes)
    }
}
