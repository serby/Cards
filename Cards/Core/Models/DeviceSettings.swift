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
    /// The units distances are shown in, a `DistanceUnits` (SET-4). Automatic
    /// until another is chosen. The widget reads a copy (`WidgetSettings`).
    public static let distanceUnitsKey = "distanceUnits"
    /// The app a card's places open in, a `MapsApp` (SET-5). Apple Maps until
    /// another is chosen.
    public static let mapsAppKey = "mapsApp"
    /// Whether the cards sync through the person's iCloud account (DATA-8). On
    /// until it is turned off in Settings; off, they are kept on this device only.
    public static let syncsWithICloudKey = "syncsWithICloud"
    /// When iCloud Sync last ended well, a `Date`, so Settings can say it after a
    /// relaunch (DATA-10). Not a setting anyone changes.
    public static let iCloudLastSyncedKey = "iCloudLastSynced"
    /// Whether the app sends its developer crash reports and performance data
    /// through Sentry (PLAT-11, PLAT-14). On until it is turned off in Settings.
    public static let sharesDiagnosticsKey = "sharesDiagnostics"
    /// Whether the app counts which features are used through Google Analytics
    /// (PLAT-15). On until it is turned off in Settings.
    public static let sharesUsageDataKey = "sharesUsageData"
}
