import Foundation

/// A card's notes (CARD-14): free text the card holder keeps with a card, such
/// as what it is for or when its points run out.
public enum CardNotes {
    /// `text` as a card keeps it: without spaces and new lines at either end,
    /// or nil when nothing else is left, so blank notes are no notes.
    public static func kept(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
