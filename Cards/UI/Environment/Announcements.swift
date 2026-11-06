import Foundation

/// Messages VoiceOver speaks after an action that changes the screen without
/// moving focus to the result, so people hear that it worked.
public enum Announcements {
    /// After cards are deleted from the list: the card by name, or how many
    /// went when several did. Cards and places have strings of their own, so
    /// a language that makes a word agree with "card" or "place" can.
    public static func deletedCards(_ names: [String]) -> String {
        if names.count == 1, let name = names.first {
            return String(
                localized: "Deleted card \(name)",
                comment: "VoiceOver announcement after one card is deleted from the list. The argument is the card's name, such as Joe's Market."
            )
        }
        return String(
            localized: "Deleted \(names.count) cards",
            comment: "VoiceOver announcement after several cards are deleted from the list at once. The argument is how many, always two or more."
        )
    }

    /// After places are deleted from a card in the card form, as
    /// `deletedCards(_:)` does for cards.
    public static func deletedPlaces(_ names: [String]) -> String {
        if names.count == 1, let name = names.first {
            return String(
                localized: "Deleted place \(name)",
                comment: "VoiceOver announcement after one place is deleted from the card form. The argument is the place's name, such as Boulder Barn."
            )
        }
        return String(
            localized: "Deleted \(names.count) places",
            comment: "VoiceOver announcement after several places are deleted from a card at once. The argument is how many, always two or more."
        )
    }

    /// After a place is added to a card in the card form.
    public static func added(_ name: String) -> AttributedString {
        var message = AttributedString(
            localized: "Added \(name)",
            comment: "VoiceOver announcement after a place is added to the card in the card form. The argument is the place's name."
        )
        // The map sheet closes as this is spoken; do not let the focus change
        // cut it off.
        message.accessibilitySpeechAnnouncementPriority = .high
        return message
    }

    /// After every card is deleted from Settings.
    public static var allCardsDeleted: String {
        String(localized: "All cards deleted", comment: "VoiceOver announcement after Delete All in Settings deletes every card.")
    }
}
