import Foundation

public extension CardItem {
    /// The order a card added now takes: after every other card.
    static func nextOrder(after cards: [CardItem]) -> Int {
        (cards.map(\.order).max() ?? -1) + 1
    }

    /// Numbers `cards` from 0 in their current order, as after one is deleted.
    static func renumber(_ cards: [CardItem]) {
        cards.sorted { $0.order < $1.order }.enumerated().forEach { index, card in
            card.order = index
        }
    }
}

/// Adding cards from an export.
public enum CardImport {
    /// What an import added, and why it left the rest out.
    public struct Result {
        public var added: [CardItem] = []
        /// Cards whose code is already in the app.
        public var alreadyHere = 0
        /// Cards whose code came earlier in the same file.
        public var repeated = 0
        /// Cards with no name or no code.
        public var incomplete = 0
    }

    /// The cards to add from `exported`, after `existing`, in the order they were
    /// exported in so that restoring a backup keeps it. Names and codes are
    /// trimmed as the edit form trims them. A card with no name or code is left
    /// out, and so is one whose code is already in the app or earlier in the
    /// file, since the code is how a card is found and importing a file twice
    /// must not duplicate it.
    public static func cards(from exported: [CardItemDTO], existing: [CardItem]) -> Result {
        let existingCodes = Set(existing.map { $0.code.trimmingCharacters(in: .whitespacesAndNewlines) })
        var fileCodes: Set<String> = []
        var order = CardItem.nextOrder(after: existing)
        var result = Result()
        // Sorted by exported order; cards without one, and ties, keep their place in the file.
        let sorted = exported.enumerated()
            .sorted { ($0.element.order ?? .max, $0.offset) < ($1.element.order ?? .max, $1.offset) }
            .map(\.element)
        for dto in sorted {
            let card = dto.toCardItem()
            card.name = card.name.trimmingCharacters(in: .whitespacesAndNewlines)
            card.code = card.code.trimmingCharacters(in: .whitespacesAndNewlines)
            if card.name.isEmpty || card.code.isEmpty {
                result.incomplete += 1
            } else if existingCodes.contains(card.code) {
                result.alreadyHere += 1
            } else if fileCodes.contains(card.code) {
                result.repeated += 1
            } else {
                card.order = order
                order += 1
                fileCodes.insert(card.code)
                result.added.append(card)
            }
        }
        return result
    }

    /// What an import did, in a sentence or two, in `locale`'s language: the
    /// app's own unless a test asks for another. Each count is a sentence of
    /// its own, so the catalogue can give it plural forms.
    public static func summary(_ result: Result, locale: Locale = .current) -> String {
        let added = result.added.count
        var summary = string(
            added == 0
                ? LocalizedStringResource(
                    "No cards imported.",
                    comment: "Import result alert when no card in the export was added. Sentences saying why may follow it."
                )
                : LocalizedStringResource(
                    "Imported \(added) cards.",
                    comment: """
                    Import result alert after cards are added from an export, pasted or chosen as a file. \
                    The argument is how many cards were added, always at least one. Sentences about cards left out may follow it.
                    """
                ),
            in: locale
        )
        for sentence in leftOut(result) {
            summary = joined(summary, string(sentence, in: locale), in: locale)
        }
        return summary
    }

    /// A sentence for each reason cards were left out, if any were.
    private static func leftOut(_ result: Result) -> [LocalizedStringResource] {
        var sentences: [LocalizedStringResource] = []
        if result.alreadyHere > 0 {
            sentences.append(LocalizedStringResource(
                "\(result.alreadyHere) were already in Card Barcodes.",
                comment: """
                Import result alert, after “Imported 3 cards.” or “No cards imported.”: how many cards were left out \
                because a card with the same code is already in the app. Card Barcodes is the app's name. \
                The argument is that number, always at least one.
                """
            ))
        }
        if result.repeated > 0 {
            sentences.append(LocalizedStringResource(
                "\(result.repeated) were in the file more than once.",
                comment: """
                Import result alert, after “Imported 3 cards.” or “No cards imported.”: how many cards were left out \
                because a card with the same code came earlier in the same export, pasted or chosen as a file. \
                The argument is that number, always at least one.
                """
            ))
        }
        if result.incomplete > 0 {
            sentences.append(LocalizedStringResource(
                "\(result.incomplete) were missing a name or code.",
                comment: """
                Import result alert, after “Imported 3 cards.” or “No cards imported.”: how many cards were left out \
                because they had no name or no code. The argument is that number, always at least one.
                """
            ))
        }
        return sentences
    }

    /// Two sentences of the import result, one after the other.
    private static func joined(_ summary: String, _ sentence: String, in locale: Locale) -> String {
        string(
            LocalizedStringResource(
                "\(summary) \(sentence)",
                comment: """
                Joins two sentences of the import result alert, as in “Imported 3 cards. 1 was already in Card Barcodes.” \
                The first argument is the result so far, the second the sentence that follows it. \
                A language that writes sentences without a space between them, such as Japanese or Chinese, leaves the space out.
                """
            ),
            in: locale
        )
    }

    /// `resource` in `locale`'s language.
    private static func string(_ resource: LocalizedStringResource, in locale: Locale) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }
}
