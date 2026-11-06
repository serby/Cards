/// The keys of the settings kept on the device, in `UserDefaults`, rather than
/// stored with the cards, so they do not sync (DATA-1).
public enum DeviceSettings {
    /// Whether the Cards tab shows the card for where you are in full above the
    /// grid (SET-3). Off until it is turned on in Settings.
    public static let showsCardWhereYouAreKey = "showsCardWhereYouAre"
    /// When the app last asked for an App Store rating and the days a card has
    /// been shown on since, a `ReviewPrompt` (PLAT-8). Not a setting anyone
    /// changes, but kept on the device the same way.
    public static let reviewPromptKey = "reviewPrompt"
    /// The order the Cards tab shows the cards in, a `CardSortOrder` (CARD-11).
    /// Custom order until another is chosen.
    public static let cardSortOrderKey = "cardSortOrder"
}
