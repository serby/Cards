# Sync and data

Where cards are kept, how they sync through iCloud, exporting and importing them as JSON, old exports, and deleting every card.

### DATA-1: Have my cards on all my devices

As a person with several devices, I want my cards to sync through my iCloud account, so that the same cards are on my iPhone and iPad.

- Cards are stored with SwiftData and mirrored to the private CloudKit database of the iCloud container `iCloud.net.serby.Cards`, in your own iCloud account.
- Everything about a card syncs: name, code, barcode type, colour, order, the date it was added, and its places.
- Adding, editing, reordering and deleting a card all reach your other devices. Deleting a card deletes it everywhere (CARD-6).
- Changes from other devices arrive when the app is opened, as the app has no push notifications from CloudKit.
- Settings (SET-1), the widget's choice of card (WID-2) and the scheduled arrival notifications (ARR-1) belong to each device and don't sync.
- There is no account to create. Signed out of iCloud, cards are kept on the device.

**Since:** 1.1
**Where:** `Cards/Core/Services/CardStore.swift`, `Cards/Cards.entitlements`, `Cards/Core/Models/CardItem.swift`
**Notes:** Debug builds sync with the Development CloudKit environment and release builds with Production, so a debug build never sees the App Store app's cards (`Cards/Cards.Debug.entitlements`).

### DATA-2: Export my cards as JSON

As a card holder, I want to export my cards, so that I have a copy I control.

- Settings > Data > "Export as JSON" opens the share sheet with every card as JSON text.
- The JSON is an array of cards, pretty-printed with sorted keys. Each card has `code`, `color`, `locations`, `name`, `order`, `timestamp` and `type`.
- `timestamp` is an ISO 8601 date. `type` is the barcode type's name, such as "EAN-13". `color` is a palette name or "#RRGGBB" (COL-8). Each place has `id`, `name`, `latitude`, `longitude` and `radius` in metres.
- The app only exports when asked.

**Since:** 1.0
**Where:** `Cards/Features/SettingsScreen.swift`, `Cards/Core/Models/CardItem.swift:56-88`, `Cards/UI/Components/ShareSheet.swift`
**Notes:** Cards are exported in no particular order. Each carries its `order`, so an import puts them back in place.

### DATA-3: Import cards from JSON

As a card holder, I want to import cards from an export, so that I can restore them or move them to a new device.

- Settings > Data > "Import JSON" opens a sheet titled "Import JSON" with a monospaced text box, "Paste from Clipboard", Cancel and Import.
- "Paste from Clipboard" replaces the box's text with the clipboard's text. Import is disabled while the box is empty.
- Import closes the sheet and adds every card in the text alongside the existing cards. Nothing is replaced or merged, so importing the same export twice gives two of each card.
- Imported cards keep their `order`, date, colour and places.
- An alert titled "Import Result" says "Successfully imported <n> cards" or, if the text isn't a JSON array of cards, "Invalid JSON format". Nothing is imported when it fails.
- A card without `code`, `name`, `order`, `timestamp` or `type`, or with a date that isn't ISO 8601, fails the whole import.

**Since:** 1.0
**Where:** `Cards/Features/SettingsScreen.swift`, `Cards/UI/Screens/SettingsListView.swift`
**Notes:** The message reads "Successfully imported 1 cards" for one card. Imported codes aren't checked against existing cards (CARD-8).

### DATA-4: Import an export from an older version

As a card holder, I want exports from any earlier version to import, so that an old backup is never wasted.

- An export without `color`, from before colours, imports with every card in Default (COL-8).
- An export without `locations`, from before places, imports with no places.
- A barcode type name the app doesn't know imports as Code 128, and a colour it doesn't know as Default.

**Since:** 1.3
**Where:** `Cards/Core/Models/CardItem.swift:56-88`, `CardsTests/CardItemTests.swift` (`exportWithoutColourStillImports`, `exportRoundTripKeepsColour`), `CardsTests/CardLocationTests.swift` (`exportWithoutLocationsImportsWithNone`, `exportRoundTripKeepsLocations`)

### DATA-5: Delete every card at once

As a card holder, I want to delete all my cards in one go, so that I can start again.

- Settings > Data > "Delete All Cards" is disabled when there are no cards (1.1).
- It asks first: "Delete All Cards", "This will permanently delete all <n> cards. This action cannot be undone.", with "Delete All" and Cancel.
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
