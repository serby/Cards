# Sync and data

Where cards are kept, how they sync through iCloud, keeping them on the device only and deleting them from iCloud, exporting and importing them as JSON, old exports, and deleting every card.

### DATA-1: Have my cards on all my devices

As a person with several devices, I want my cards to sync through my iCloud account, so that the same cards are on my iPhone and iPad.

- Cards are stored with SwiftData and mirrored to the private CloudKit database of the iCloud container `iCloud.net.serby.Cards`, in your own iCloud account.
- Everything about a card syncs: name, code, barcode type, colour, order, the date it was added, its places, and whether it reminds you on arrival (ARR-6).
- Since 1.4: its notes sync with it too (CARD-14).
- Adding, editing, reordering and deleting a card all reach your other devices. Deleting a card deletes it everywhere (CARD-6).
- Changes from other devices arrive when the app is opened, as the app has no push notifications from CloudKit.
- Settings (SET-1), the widget's choice of card (WID-2) and the scheduled arrival notifications (ARR-1) belong to each device and don't sync. A card's own arrival switch syncs with the card, but the Arrival Notifications switch in Settings is set on each device (ARR-5).
- There is no account to create. Signed out of iCloud, or with iCloud Sync off (DATA-8), cards are kept on the device.

**Since:** 1.1
**Where:** `Cards/Core/Services/CardStore.swift`, `Cards/Cards.entitlements`, `Cards/Core/Models/CardItem.swift`
**Notes:** Debug builds sync with the Development CloudKit environment and release builds with Production, so a debug build never sees the App Store app's cards (`Cards/Cards.Debug.entitlements`).

### DATA-2: Export my cards as JSON

As a card holder, I want to export my cards, so that I have a copy I control.

- Settings > Data > "Export as JSON" opens the share sheet with every card as JSON text.
- In preparation for 1.5: the share sheet gets a file rather than text, named "Card Barcodes <date>.json" with the day's date where the device is, as year, month and day, such as "Card Barcodes 2026-11-13.json". The date is the device's day in its own time zone, so an export made late at night in London or early in the morning in Tokyo is named for that day there. The name is the same in every language, as Card Barcodes is the app's name in all of them, and its digits are always 0 to 9. The share sheet shows the file's name, Save to Files keeps it under that name as a JSON file, and Mail, Messages and AirDrop send it as an attachment. Until 1.5 the share sheet got the JSON as text, which Save to Files kept as a text file under a name of its own.
- In preparation for 1.5: if the file can't be written, as when the device is full, the share sheet gets the JSON as text instead, as it did before.
- The JSON is an array of cards, pretty-printed with sorted keys. Each card has `code`, `color`, `locations`, `name`, `notifiesOnArrival`, `order`, `timestamp` and `type`.
- `timestamp` is an ISO 8601 date. `type` is the barcode type's name, such as "EAN-13". `color` is a palette name or "#RRGGBB" (COL-8). Each place has `id`, `name`, `latitude`, `longitude` and `radius` in metres. `notifiesOnArrival` is `true` or `false`, the card's own arrival switch (ARR-6) (1.3).
- Since 1.4: a card with notes also has `notes`, the text as the card keeps it (CARD-14). A card without notes has no `notes` key.
- Cards are exported in their list order (1.3).
- The app only exports when asked.

**Since:** 1.0
**Where:** `Cards/Features/SettingsScreen.swift` (`export`), `Cards/Core/Models/CardExport.swift`, `Cards/Core/Services/FileWriter.swift`, `Cards/Core/Models/CardItem.swift` (`CardItemDTO`), `Cards/UI/Components/ShareSheet.swift`, `Cards/Core/Services/FileWriter.swift` (`removeHandedOver`), `CardsTests/ExportFileTests.swift` (`HandedOverFileTests`)
**Notes:** Before 1.3 cards were exported in no particular order, but each carries its `order`, so an older export still restores in its order (DATA-3). The file is written to a folder of the app's temporary files that holds only the latest export, so exports from other days do not pile up, and iOS clears it out in time.

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
- Since 1.4: an export without `notes`, from before notes, imports with no notes, and notes that are only spaces and new lines import as none (CARD-14).
- A barcode type name the app doesn't know, or none, imports as Code 128, and a colour it doesn't know as Default.
- A card without `order` or `timestamp`, as in a hand-written file, still imports (DATA-3).

**Since:** 1.3
**Where:** `Cards/Core/Models/CardItem.swift:61-98`, `CardsTests/CardItemTests.swift` (`exportWithoutColourStillImports`, `exportRoundTripKeepsColour`), `CardsTests/CardLocationTests.swift` (`exportWithoutLocationsImportsWithNone`, `exportRoundTripKeepsLocations`), `CardsTests/CardFixesTests.swift` (`notifyingIsKeptAndOlderExportsNotify`), `CardsTests/CardNotesTests.swift` (`anExportFromBeforeNotesImportsWithNone`, `blankNotesInAnExportImportAsNone`)

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

### DATA-7: Import cards from a file

As a card holder, I want to import an export saved as a file, so that I don't have to copy and paste its text.

- The Import JSON sheet (DATA-3) has a "Choose File" button beside "Paste from Clipboard", or below it at the accessibility text sizes. It opens the Files picker, limited to JSON files. In preparation for 1.5 it takes text files too, so an export saved to Files before 1.5, which was kept as a text file and could not be chosen, can be.
- In preparation for 1.5: a file made by Export as JSON (DATA-2) and saved to Files imports every card in it as it was exported, by Choose File, on another device or on the same one after its cards are deleted. On the device it came from, with its cards still there, it adds nothing (DATA-3). A test exports cards to a file and imports that file back, end to end.
- In preparation for 1.5: an export can also be opened in the app from Files, Mail or AirDrop, without Choose File (DATA-11).
- Choosing a file closes the sheet and imports its cards with the same rules and messages as pasted text (DATA-3, DATA-4): duplicates are skipped and the rest are added at the end. Any text in the box is left out and cleared.
- Cancelling the Files picker goes back to the sheet, and imports nothing.
- A file that cannot be read, or is not a card export, shows "Invalid JSON format", and nothing is imported.

**Since:** 1.4
**Where:** `Cards/UI/Screens/SettingsListView.swift`, `Cards/UI/Screens/ImportCardsView.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/Core/Services/FileReader.swift`, `Cards/Core/Models/CardImport.swift`, `CardsTests/ImportFileTests.swift`, `CardsTests/ExportFileTests.swift` (`anExportedFileImportsTheSameCardsOnAnotherDevice`, `anExportedFileAddsNothingWhereItsCardsAlreadyAre`, `anExportSavedAsTextBefore15Imports`)

### DATA-8: Keep my cards on this device only

As a card holder, I want to turn iCloud sync off, so that my cards stay on this device and nowhere else.

- Settings > iCloud has an "iCloud Sync" switch with the caption "Keeps your cards in your iCloud account, so they are on all your devices. Turn it off to keep them on this device only." It is on until you turn it off.
- Turning it off reopens the store without iCloud, on the same file, so every card stays on the device and nothing more is sent to iCloud or taken from it. The app's screens are built again on the new store, so Settings shows again where it was. Turning it back on syncs again (DATA-1).
- While it is off, export and import (DATA-2, DATA-3) are the way to move cards to another device.
- The switch is kept on the device under `syncsWithICloud` and doesn't sync, so each device has its own.
- The cards already in iCloud stay there until you delete them (DATA-9).

**Since:** 1.4
**Where:** `Cards/Core/Services/CardStore.swift`, `Cards/App/CardsApp.swift`, `Cards/UI/Screens/SettingsListView+Privacy.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/Core/Models/DeviceSettings.swift`, `CardsTests/CardStoreTests.swift`
**Notes:** UI tests use an in-memory store, which never syncs, so the switch doesn't reopen it there. A store that has synced keeps saving once it is opened without iCloud, and the other way round (`CardStoreTests`).

### DATA-9: Delete my cards from iCloud

As a card holder who has turned iCloud sync off, I want to delete the copy of my cards in iCloud, so that none of my cards are kept there.

- With iCloud Sync off, Settings > iCloud shows "Delete Cards from iCloud" under the switch, with the caption "Your cards stay in iCloud until you delete them there."
- It asks first, in a dialog titled "Delete Cards from iCloud" with the message "This deletes your cards from iCloud. The cards on this device are kept.", "Delete from iCloud" and "Cancel".
- Deleting removes the zone of the app's private CloudKit database that holds every card (`com.apple.coredata.cloudkit.zone` in `iCloud.net.serby.Cards`). The cards on this device are untouched.
- While it runs, the caption says "Deleting your cards from iCloud…" beside a spinner, and the button is off. Then it says "Your cards are no longer in iCloud. A device that still has iCloud Sync on will upload its cards again.", or, when iCloud can't be reached or you are not signed in, "Your cards could not be deleted from iCloud. Check that you're signed in to iCloud and online, then try again." VoiceOver reads the result when it comes.
- Nothing in iCloud to delete counts as deleted.
- Turning iCloud Sync on again clears the caption.

**Since:** 1.4
**Where:** `Cards/Core/Services/ICloudCards.swift`, `Cards/UI/Screens/SettingsListView+Privacy.swift`, `Cards/Features/SettingsScreen.swift`, `CardsTests/PrivacySettingsTests.swift`
**Notes:** Only the device that deletes stops syncing. Another device with iCloud Sync on uploads its cards again, as the caption says.

### DATA-10: See whether my cards are syncing

As a card holder with iCloud Sync on, I want to see how syncing is going, so that I know my cards are on my other devices, or why they are not.

- With iCloud Sync on (DATA-8), Settings > iCloud shows a status under the switch: a symbol, a line saying where syncing has got to, and a caption under it when there is more to say. With iCloud Sync off it shows no status, and Delete Cards from iCloud instead (DATA-9).
- "Checking iCloud…" with a spinner, just after the app opens, before anything is known.
- "Syncing…" with a spinner, while cards are being sent to iCloud or fetched from it.
- "Up to date" with a cloud and a tick, and "Last synced 3 minutes ago", counting on while it shows, once syncing has ended well.
- "Not signed in to iCloud", in the warning colour, with "Sign in to iCloud in the Settings app to sync your cards.", when no one is signed in on the device.
- "iCloud isn't available" with "Your cards stay on this device until iCloud is available again.", when iCloud is restricted, as by Screen Time, or not available for now.
- "Waiting for a connection", with a crossed-out cloud, when the device is offline or iCloud can't be reached, with when it last synced, or "Your changes sync once this device is online." if it never has.
- "iCloud storage is full", in the warning colour, with "Your cards sync again once there is room in your iCloud account."
- "Couldn't sync" for any other failure, with when it last synced, or "Card Barcodes tries again by itself."
- The app follows syncing from the moment it opens, so the status is current as soon as Settings shows, and signing in or out of iCloud while it runs changes it. When syncing last ended well is kept on the device, so after a relaunch the status says when it last synced until syncing starts again.
- VoiceOver reads the status and its caption as one element.

**Since:** In preparation for 1.5
**Where:** `Cards/Core/Models/ICloudSyncStatus.swift` (`ICloudSyncTracker`), `Cards/Core/Services/ICloudSync.swift`, `Cards/Features/ICloudSyncMonitor.swift`, `Cards/App/CardsApp.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/UI/Screens/SettingsListView+Privacy.swift` (`iCloudSyncStatusRow`), `Cards/Core/Models/DeviceSettings.swift` (`iCloudLastSyncedKey`), `Cards/App/DevelopmentHooks.swift` (`iCloudSync`), `CardsTests/ICloudSyncStatusTests.swift`
**Notes:** The status comes from the events SwiftData's CloudKit mirroring posts (`NSPersistentCloudKitContainer.eventChangedNotification`), each piece of setting up, fetching or sending from its start to its end, and from the account's status (`CKContainer.accountStatus()`, again on `CKAccountChanged`). UI tests and the App Store screenshots, whose store is in memory and never syncs, show it up to date as of three minutes before.

### DATA-11: Open an export in the app

As a card holder, I want to open an export from Files, Mail or AirDrop straight in Card Barcodes, so that I don't have to find it again with Choose File.

- The app tells iOS it can open JSON files, as an alternative to the apps that own them, so iOS offers Card Barcodes for a JSON file, such as an export (DATA-2), but never makes it the app that opens JSON files.
- Opening a JSON file in Card Barcodes brings the app forward on the Settings tab, launching it if it was not running, and imports the file with the same rules and result message as Choose File (DATA-3, DATA-4, DATA-7): duplicates are skipped, the rest are added at the end, and the "Import Result" alert says what happened. A file that is not a card export shows "Invalid JSON format", and nothing is imported.
- iOS hands the app a copy of the file, so the file in Files, the mail or the AirDrop is left as it was. The app deletes its copy once it has imported it, as the copy holds every card in the export.
- The "Add Card?" sheet (SHARE-3) and the export share sheet (DATA-2), if either was showing, close to make way for the result. The Cards tab keeps what it was showing (NAV-1).
- Only JSON files are offered to the app. An export saved to Files before 1.5, kept as a text file, imports with Choose File (DATA-7).

**Since:** In preparation for 1.5
**Where:** `Info.plist` (`CFBundleDocumentTypes`, `LSSupportsOpeningDocumentsInPlace`), `Cards/App/CardsApp.swift`, `Cards/Core/Navigation/NavigationManager.swift` (`handleDeepLink`, `importFile`), `Cards/Features/SettingsScreen.swift`, `CardsTests/NavigationTests.swift` (`anOpenedFileIsImportedInSettings`, `linksAreNotImported`), `CardsTests/ExportFileTests.swift`
