# Widget

A medium Home Screen widget that shows one card's barcode, big enough to scan: the card nearest to you, or one you choose.

### WID-1: See the nearest card's barcode on my Home Screen

As a card holder, I want my Home Screen to show the card for where I am, so that I can scan it without opening the app.

- The widget comes in the medium size only. In the widget gallery it is called "Card", described as "Shows the barcode of the card nearest to you, or one you choose."
- By default it shows the card whose nearest place is closest to you, measured to the edge of each place's circle (PLACE-6), with its distance and place name. In preparation for 1.4 the distance is in the units chosen in the app's Settings (SET-4).
- When no card has a place, or the widget has no location, it shows the first card in the list's own order (CARD-7), whichever way the list is sorted.
- It only asks for a location when some card has a place, and only when iOS lets the widget use location (`isAuthorizedForWidgetUpdates`). iOS describes it as "Your location lets the widget show the card for the place you are at."
- It uses a reading up to 2 minutes old when there is one (1.3). Otherwise it waits up to 10 seconds for a new one.
- In preparation for 1.4: iOS only gives the widget your location for about 15 minutes after it was last on screen. After that Core Location reports it "insufficiently in use" and gives it nothing, not even the device's last reading, so every reload while the phone sat unused showed the first card with no distance. The widget now keeps each good reading, in `widget-location.json` in the App Group, and a reload without a new one uses the newer of the device's last reading and the kept one. So it keeps showing the card for where you were last seen, with its distance from there, and only shows the first card when it has never had a reading. If you have moved since, it shows the card for where you were until a reload gets your new location: iOS reloads a location widget the next time you look at it after a significant location change, and the refresh button reloads it at once (WID-3).
- The preview in the widget gallery shows your cards without asking for a location.

**Since:** 1.3
**Where:** `CardsWidget/CardWidget.swift`, `CardsWidget/WidgetLocation.swift`, `Cards/Core/Models/WidgetCard.swift`, `Cards/Core/Services/WidgetLastLocation.swift`, `CardsTests/WidgetTests.swift` (`lastLocationRoundTripsAndKeepsTheNewest`, `bestReadingIsTheNewOneOrElseTheNewerOfTheOthers`)
**Notes:** In the simulator the widget gets no location, even when the app is launched with the screenshot location, because the widget asks Core Location itself. It then shows the top card with no distance, as in `screenshots/en-GB/05_Widget.png`.

### WID-2: Choose which card the widget shows

As a card holder, I want to pin a card to the widget, so that the card I use most is always there.

- Editing the widget (long-press, Edit Widget) offers "Choose Card", "Pick a card, or let the widget show the one nearest to you.", with one Card setting.
- The choices are "Nearest card", the default, and every card by name.
- A chosen card is always shown, wherever you are, with its distance when the widget has a location.
- If the chosen card is deleted, or its code changes (CARD-5), the widget goes back to showing the nearest card.
- Each widget on the Home Screen has its own choice.

**Since:** 1.3
**Where:** `CardsWidget/CardWidgetIntents.swift`, `CardsWidget/CardWidget.swift:66-77`

### WID-3: Find the nearest card again after moving

As a card holder, I want to refresh the widget when I have moved, so that it shows the card for my new place without waiting.

- While the widget is showing the nearest card and some card has a place, it has a round refresh button labelled "Find nearest card" for VoiceOver.
- Tapping it reloads the widget, which looks for a fresh location and picks the nearest card again (WID-1).
- On its own, a nearest-card widget asks WidgetKit to reload after 15 minutes. WidgetKit can space reloads out further when its daily budget runs low.
- A widget with a chosen card, or with no places to compare, has no refresh button and only reloads when the app's cards change (WID-7).

**Since:** 1.3
**Where:** `CardsWidget/CardWidget.swift:33-92`, `CardsWidget/CardWidgetIntents.swift:57-66`

### WID-4: Open the card from the widget

As a card holder, I want to tap the widget to open the card, so that I can show it full size with the brightness up.

- Tapping the widget, away from the refresh button, opens the app on that card's screen, through its `cards://cards/card/<code>` link (NAV-2).
- Any code works in the link, including codes with "/", spaces or accented letters.
- The link brings the Cards tab forward, so the card shows even when Settings was open (NAV-1).
- With no cards, tapping the widget opens the app.

**Since:** 1.3
**Where:** `CardsWidget/CardWidget.swift:15`, `Cards/UI/ViewState/CardWidgetState.swift`, `Cards/Core/Navigation/NavigationRoute.swift`, `Cards/Core/Navigation/NavigationManager.swift`, `CardsTests/NavigationTests.swift` (`cardLinksRoundTripAnyCode`), `CardsTests/CardFixesTests.swift` (`openingACardBringsTheCardsTabForward`)

### WID-5: Read the widget at a glance

As a card holder, I want the widget laid out for its barcode, so that the code is as big as the space allows.

- The widget's background is the card's gradient (COL-6), or the system background for a Default card.
- A strip barcode (BAR-1) runs the full width under a white panel holding the name on one line, the distance and place, and the refresh button.
- A square code, QR Code or Aztec, sits on the right, beside a white panel holding the name on up to two lines, the distance and place, and the number in small monospaced type, with the refresh button at the bottom.
- The strip layout doesn't show the number.
- Panels and the barcode's white use the widget's own corner shape, so their corners nest inside it on every device.
- A code that can't be drawn shows "This code can't be drawn" in place of the barcode.
- With no cards, the widget shows "No cards yet" and "Add a card in Card Barcodes and it shows here."
- VoiceOver reads the widget as one item, such as "Joe's Market, 120 m from Joe's Market Notting Hill", with the hint "Opens the card in Card Barcodes". The barcode image is hidden from VoiceOver.

**Since:** 1.3
**Where:** `Cards/UI/Components/CardWidgetView.swift`, `CardsWidget/CardWidget.swift:9-23`

### WID-6: Use the widget on a tinted or clear Home Screen

As a card holder, I want the widget to work with any Home Screen style, so that I don't have to choose between my look and my barcode.

- On a tinted or clear Home Screen the white panels drop their fill, and the text takes the Home Screen's tint.
- The barcode stays one full-colour image, black bars on white, so it still scans.

**Since:** 1.3
**Where:** `Cards/UI/Components/CardWidgetView.swift:11-13`, `Cards/UI/Components/CardWidgetView.swift:125-162`

### WID-7: Keep the widget up to date with my cards

As a card holder, I want the widget to reflect the cards I have, so that it never shows a card I have deleted or misses a new one.

- The widget can't open the app's store, so the app keeps a copy of every card for it: name, code, barcode type, colour and places, in list order.
- The copy is a JSON file, `widget-cards.json`, in the App Group `group.net.serby.Cards`.
- The Cards list writes the copy whenever its cards change, and only reloads the widget when the file's contents change.
- Until the app has written the copy, or if it can't be read, the widget shows its empty state (WID-5).
- In preparation for 1.4: the app also copies the Distances choice (SET-4) to `widget-settings.json` in the same App Group, as `{"distanceUnits":"miles"}`, when it starts and whenever the choice changes, and reloads the widget only when that changes the file. Without a copy, or with one it can't read, the widget writes distances as Automatic does.

**Since:** 1.3
**Where:** `Cards/Core/Services/WidgetSnapshot.swift`, `Cards/Features/CardListScreen.swift`, `Cards/Features/CardListScreen.swift`, `Cards/Core/Services/WidgetSettings.swift`, `Cards/App/CardsApp.swift`, `CardsTests/WidgetTests.swift` (`snapshotRoundTripsAndSkipsUnchangedWrites`, `snapshotThatCannotBeReadIsEmpty`, `snapshotWithoutAnAppGroupReadsAndWritesNothing`, `settingsRoundTripAndSkipUnchangedWrites`, `settingsThatCannotBeReadAreAutomatic`, `settingsWithoutAnAppGroupReadAutomaticAndWriteNothing`)
**Notes:** Only the app writes the copy, so cards that arrive through iCloud reach the widget once the app is opened on that device. A new widget added before the app has ever been opened shows "No cards yet".
