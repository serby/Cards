import Foundation

/// Messages VoiceOver speaks after an action that changes the screen without
/// moving focus to the result, so people hear that it worked.
public enum Announcements {
    /// After cards are deleted from the list, or places from a card: "Deleted
    /// Tesco Clubcard", "Deleted Tesco Clubcard and Boots Advantage".
    public static func deleted(_ names: [String]) -> String {
        String(
            localized: "Deleted \(names.formatted(.list(type: .and)))",
            comment: "VoiceOver announcement after deleting cards from the list or a place from a card. The argument is a name, or a list of names."
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
