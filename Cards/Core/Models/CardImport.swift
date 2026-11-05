import Foundation

public extension CardItem {
    /// The order a card added now takes: after every other card.
    static func nextOrder(after cards: [CardItem]) -> Int {
        (cards.map(\.order).max() ?? -1) + 1
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

    /// What an import did, in a sentence or two.
    public static func summary(_ result: Result) -> String {
        let added = result.added.count
        var sentences = [added == 0 ? "No cards imported." : "Imported \(cardCount(added))."]
        if result.alreadyHere > 0 {
            sentences.append("\(wasOrWere(result.alreadyHere)) already in Card Barcodes.")
        }
        if result.repeated > 0 {
            sentences.append("\(wasOrWere(result.repeated)) in the file more than once.")
        }
        if result.incomplete > 0 {
            sentences.append("\(wasOrWere(result.incomplete)) missing a name or code.")
        }
        return sentences.joined(separator: " ")
    }

    /// "1 was", "2 were".
    private static func wasOrWere(_ count: Int) -> String {
        count == 1 ? "1 was" : "\(count) were"
    }
}

/// "1 card", "3 cards".
public func cardCount(_ count: Int) -> String {
    count == 1 ? "1 card" : "\(count) cards"
}
