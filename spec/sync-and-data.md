# Sync and data

Where cards are kept, how they sync through iCloud, exporting and importing them as JSON, old exports, and deleting every card.

### DATA-1: Have my cards on all my devices

As a person with several devices, I want my cards to sync through my iCloud account, so that the same cards are on my iPhone and iPad.

- Cards are stored with SwiftData and mirrored to the private CloudKit database of the iCloud container `iCloud.net.serby.Cards`, in your own iCloud account.
- Everything about a card syncs: name, code, barcode type, colour, order, the date it was added, its places, and whether it reminds you on arrival (ARR-6).
- Adding, editing, reordering and deleting a card all reach your other devices. Deleting a card deletes it everywhere (CARD-6).
- Changes from other devices arrive when the app is opened, as the app has no push notifications from CloudKit.
- Settings (SET-1), the widget's choice of card (WID-2) and the scheduled arrival notifications (ARR-1) belong to each device and don't sync. A card's own arrival switch syncs with the card, but the Arrival Notifications switch in Settings is set on each device (ARR-5).
- There is no account to create. Signed out of iCloud, cards are kept on the device.

**Since:** 1.1
**Where:** `Cards/Core/Services/CardStore.swift`, `Cards/Cards.entitlements`, `Cards/Core/Models/CardItem.swift`
**Notes:** Debug builds sync with the Development CloudKit environment and release builds with Production, so a debug build never sees the App Store app's cards (`Cards/Cards.Debug.entitlements`).

### DATA-2: Export my cards as JSON

As a card holder, I want to export my cards, so that I have a copy I control.

- Settings > Data > "Export as JSON" opens the share sheet with every card as JSON text.
- The JSON is an array of cards, pretty-printed with sorted keys. Each card has `code`, `color`, `locations`, `name`, `notifiesOnArrival`, `order`, `timestamp` and `type`.
- `timestamp` is an ISO 8601 date. `type` is the barcode type's name, such as "EAN-13". `color` is a palette name or "#RRGGBB" (COL-8). Each place has `id`, `name`, `latitude`, `longitude` and `radius` in metres. `notifiesOnArrival` is `true` or `false`, the card's own arrival switch (ARR-6) (1.3).
- Cards are exported in their list order (1.3).
- The app only exports when asked.

**Since:** 1.0
**Where:** `Cards/Features/SettingsScreen.swift`, `Cards/Core/Models/CardItem.swift:61-98`, `Cards/UI/Components/ShareSheet.swift`
**Notes:** Before 1.3 cards were exported in no particular order, but each carries its `order`, so an older export still restores in its order (DATA-3).

### DATA-3: Import cards from JSON

As a card holder, I want to import cards from an export, so that I can restore them or move them to a new device.

- Settings > Data > "Import JSON" opens a sheet titled "Import JSON" with a monospaced text box, "Paste from Clipboard", Cancel and Import.
- "Paste from Clipboard" replaces the box's text with the clipboard's text. Import is disabled while the box is empty.
- Import closes the sheet and adds the cards in the text after the existing cards (1.3). Nothing is replaced or merged.
- The cards keep the order they were exported in: they are added by their `order`, and cards without one, or with the same one, keep their place in the text (1.3).
- Names and codes are trimmed as the form trims them (CARD-3). A card with no name or no code is skipped (1.3).
- A card whose code is already in the app, or earlier in the same text, is skipped, so importing the same export twice adds nothing the second time (CARD-9) (1.3).
- Imported cards keep their date, colour, places and arrival switch (ARR-6).
- An alert titled "Import Result" says what happened (1.3). It reads "Imported 1 card." or "Imported 3 cards.", or "No cards imported." when nothing is added. A sentence follows for each reason cards were skipped: "1 was already in Card Barcodes.", "2 were in the file more than once." and "1 was missing a name or code."
- If the text isn't a JSON array of cards, the alert says "Invalid JSON format". Nothing is imported when it fails.
- Only `code` and `name` are needed. A card without `timestamp` is dated when it is imported, and one without `type` is Code 128 (1.3). A card without `code` or `name`, or with a date that isn't ISO 8601, fails the whole import.

**Since:** 1.0
**Where:** `Cards/Features/SettingsScreen.swift`, `Cards/Core/Models/CardImport.swift`, `Cards/UI/Screens/SettingsListView.swift`, `CardsTests/CardFixesTests.swift` (`importSkipsCardsAlreadyThereAndAppendsInExportedOrder`, `importKeepsFileOrderWithoutAnExportedOrder`, `importSummaryCountsProperly`)
**Notes:** Before 1.3 every card was added as it was in the text, so importing an export twice gave two of each card, and every card needed `order`, `timestamp` and `type`.

### DATA-4: Import an export from an older version

As a card holder, I want exports from any earlier version to import, so that an old backup is never wasted.

- An export without `color`, from before colours, imports with every card in Default (COL-8).
- An export without `locations`, from before places, imports with no places.
- An export without `notifiesOnArrival`, from before each card had its own arrival switch, imports with every card switched on (ARR-6).
- A barcode type name the app doesn't know, or none, imports as Code 128, and a colour it doesn't know as Default.
- A card without `order` or `timestamp`, as in a hand-written file, still imports (DATA-3).

**Since:** 1.3
**Where:** `Cards/Core/Models/CardItem.swift:61-98`, `CardsTests/CardItemTests.swift` (`exportWithoutColourStillImports`, `exportRoundTripKeepsColour`), `CardsTests/CardLocationTests.swift` (`exportWithoutLocationsImportsWithNone`, `exportRoundTripKeepsLocations`), `CardsTests/CardFixesTests.swift` (`notifyingIsKeptAndOlderExportsNotify`)

### DATA-5: Delete every card at once

As a card holder, I want to delete all my cards in one go, so that I can start again.

- Settings > Data > "Delete All Cards" is disabled when there are no cards (1.1).
- It asks first: "Delete All Cards", "This will permanently delete all <n> cards. This action cannot be undone.", with "Delete All" and Cancel.
- With one card the message reads "This will permanently delete your card. This action cannot be undone." (1.3).
- "Delete All" deletes every card. With iCloud, they are deleted on every device (DATA-1).

**Since:** 1.0
**Where:** `Cards/UI/Screens/SettingsListView.swift`, `Cards/Features/SettingsScreen.swift`, `CardsTests/SettingsViewTests.swift`
**Notes:** `SettingsViewTests` only checks the store's card count. No test covers the button itself.

### DATA-6: Keep my cards where they have always been

As a card holder, I want my cards to survive every update, so that I never lose them.

- The store is `default.store` in the app's own Application Support folder, where every version has kept it.
- It is not in the App Group the widget shares. The widget gets its own copy of the cards (WID-7).
- Each stored field has a default, and stored names for types and colours are read tolerantly (BAR-1, COL-8), so data from a newer build still opens.

**Since:** 1.0
**Where:** `Cards/Core/Services/CardStore.swift`, `Cards/Core/Models/CardItem.swift`, `CardsTests/CardStoreTests.swift`
**Notes:** SwiftData puts its default store in the first App Group in the entitlements. The widget added one in 1.3, so the store is pinned to the app's container with `groupContainer: .none`; without it every existing card would be left behind in the old file.
