# Apple Watch

The Card Barcodes app on Apple Watch: the cards from the iPhone, a list of them, each card's barcode drawn on the watch, and the card for where you are opened by itself.

### WATCH-1: Get my cards on my Apple Watch

As a card holder with an Apple Watch, I want my cards on my watch, so that I can show a barcode with my phone in my pocket.

- The watch app comes inside the iPhone app. It is a companion of the iPhone app (`WKCompanionAppBundleIdentifier` `net.serby.Cards`), not a watch-only app, and runs on watchOS 11 and later, which pairs with iOS 18, the iPhone app's oldest iOS (PLAT-1). It is called "Card Barcodes", as on the iPhone.
- The iPhone sends the watch every card, in the list's own order (CARD-7): its name, code, barcode type, colour, icon and places, and its barcode ready drawn. A card's notes (CARD-14) stay on the phone.
- watchOS cannot draw barcodes as the iPhone does, so the phone reads each barcode off its own drawing (BAR-1) as a grid of dark and light modules, one bit each, and sends that. The watch draws the grid, so it shows exactly the bars and squares the phone shows. A code that can't be drawn (BAR-3) goes without a barcode.
- It also sends the Distances choice (SET-4), so the watch writes distances in the same units.
- The Cards list sends the cards whenever they or the Distances choice change, beside the widget's copy (WID-7), and once each time the app starts. It sends only to a paired watch with the app on it, keeps the newest cards until the watch can take them, and never sends the same cards twice in a row.
- The cards travel by WatchConnectivity, straight from the iPhone to the Apple Watch paired with it, as JSON compressed with LZFSE. Up to 48 KB, about four hundred ordinary cards, they go as the application context, which keeps only the newest and reaches the watch even while its app is closed. Larger, they go as a file, any older file still on its way is cancelled, and the watch keeps whichever the phone sent last.
- The watch keeps the last cards it received in `watch-cards.json` in its own container, so the app opens on them at once, works with the phone away or switched off, and works with iCloud Sync off (DATA-8).

**Since:** In preparation for 1.5
**Where:** `Cards/Core/Models/WatchCard.swift`, `Cards/Core/Models/BarcodeModules.swift`, `Cards/UI/Components/BarcodeModules+Image.swift`, `Cards/Features/WatchCard+CardItem.swift`, `Cards/Core/Services/WatchSync.swift`, `Cards/Features/CardListScreen.swift`, `CardsWatch/Services/PhoneLink.swift`, `CardsWatch/Services/WatchCards.swift`, `CardsWatch/Services/WatchSnapshotFile.swift`, `CardsTests/WatchTests.swift`
**Notes:** Only the iPhone app sends the cards, so a change that reaches the phone through iCloud reaches the watch once the app is opened on the phone. The phone sends again on each launch, as it only remembers what it sent while it runs.

### WATCH-2: See my cards on my watch

As a card holder, I want a list of my cards on my watch, so that I can pick the one I need.

- The list is titled "Cards" and shows every card in the iPhone list's own order (CARD-7), whichever way the phone's list is sorted.
- Each row is the card's colour at full strength, with its gradient (COL-6), or the watch's grey for a Default card, and shows the card's icon if it has one (CARD-12), its name, and how far away its nearest place is when the watch knows where it is (PLACE-6), or "Here" inside one. Text on the colour is in the colour's ink.
- Distances are in the units chosen on the iPhone (SET-4), measured from where the watch is (WATCH-4).
- Tapping a row opens the card's screen (WATCH-3).
- VoiceOver reads a row as one button: the name, then the distance in full, as in "Joe's Market, 350 metres from Joe's Market Notting Hill". The icon is hidden from VoiceOver.
- Before any cards have arrived, and when the phone has none, the watch shows "No Cards Yet" and "Open Card Barcodes on your iPhone, and your cards show here."

**Since:** In preparation for 1.5
**Where:** `CardsWatch/UI/WatchCardListView.swift`, `CardsWatch/Features/WatchCardsScreen.swift`, `CardsWatch/UI/WatchColors.swift`

### WATCH-3: Show a card's barcode on my watch

As a card holder, I want my watch to show the card's barcode big enough to scan, so that the shop can scan my wrist.

- The card's screen shows its name in the bar at the top, beside Back, so the code has the screen, and its code below the barcode, in small monospaced type that reads left to right in every language. The background is the card's gradient, or black for a Default card, and the text is in the colour's ink, the name in the bar too.
- A strip barcode fills the width. A square code, such as a QR code, takes up to 70% of the screen's height, so all of it shows without scrolling, as a scanner needs.
- The barcode is black on a white plate across the screen, with the quiet zone a scanner needs: 10 modules each side of a strip barcode, 4 round a QR code and 2 round an Aztec code or a PDF417. A QR or Aztec code is square; a strip barcode is twice as wide as it is high; a PDF417 keeps its own shape.
- Each module takes a whole number of the screen's pixels where at least one fits, so every bar is the same width and its edges are sharp; a code too long for that is drawn to fit the width. The barcode never mirrors.
- A code that can't be drawn shows "This code can't be drawn" on the plate, with the code below. So does a strip barcode with more bars than the watch's screen has pixels across, such as a long Code 39, which would blur to grey and not scan.
- VoiceOver reads the barcode as "Barcode", with its type as the value, such as "EAN-13", and spells the code out character by character. The plate keeps its colours under Smart Invert. Text follows the watch's text size.
- The screen scrolls when the name and barcode are taller than the display.

**Since:** In preparation for 1.5
**Where:** `CardsWatch/UI/WatchCardView.swift`, `CardsWatch/UI/WatchBarcodeView.swift`, `CardsTests/WatchTests.swift` (`BarcodeModulesTests`, `BarcodeModulesVisionTests`)
**Notes:** watchOS has no brightness boost (BAR-4), and since watchOS 7 no public way for an app to stay in front for longer once the wrist is lowered (`isFrontmostTimeoutExtended` is no longer supported), so the watch's own Return to Clock setting decides how long the barcode stays. The Vision test that reads the watch's drawing runs on a device, as Vision cannot detect barcodes in the simulator.

### WATCH-4: Open the card for where I am

As a card holder, I want my watch to open the right card when I get to the shop, so that the barcode is ready when I raise my wrist.

- Each time the app opens or comes to the front, it finds where the watch is with the watch's own location, and asks for location access While Using the App the first time, with the reason "Your location is used to show how far you are from your cards' places, and to open the card for the place you are at."
- It uses a reading up to 2 minutes old when there is one, and otherwise waits up to 10 seconds for a new one. Without access or a reading, it shows the list.
- Inside one of a card's places, by the rule the iPhone's "Here" follows (PLACE-6, SET-3), it opens that card's screen at once. Inside several, the place whose middle is nearest wins, and on a tie the card higher in the list.
- It does this once per arrival: going back to the list leaves the list showing, even when the app comes to the front again in the same place. The watch keeps the arrival, so watchOS ending the app in the background does not open the card again. The arrival ends when the watch is found outside every place; arriving at another place opens its card.
- If you open a card yourself while the watch is still finding where it is, it leaves your choice alone.

**Since:** In preparation for 1.5
**Where:** `Cards/Core/Models/WatchCard.swift` (`arrival(at:)`, `WatchArrivals`), `CardsWatch/Features/WatchCardsScreen.swift`, `CardsWatch/Services/WatchLocation.swift`, `CardsTests/WatchTests.swift` (`WatchCardTests`)
**Notes:** The arrival is remembered only while the app runs, so after watchOS ends the app, opening it in the same place opens the card again.

### WATCH-5: Open the card from an arrival notification on my watch

As a card holder, I want to tap the arrival reminder on my watch to see the card, so that I don't need my phone at the till.

- The iPhone's arrival notification (ARR-1) shows on the watch when iOS forwards it there, as it does when the phone is locked and the watch is on your wrist.
- Tapping it on the watch opens the watch app on that card's screen, found by the code it carries (`ArrivalAlert.codeKey`), in place of whatever the app showed.
- The handler is set before launch finishes, so a tap that launches the app reaches it. The card for where you are (WATCH-4) does not replace the card a notification opened in the minute after.
- If the card is not on the watch, the screen says "Card not found".

**Since:** In preparation for 1.5
**Where:** `Cards/Features/ArrivalNotificationRouter.swift`, `CardsWatch/App/CardsWatchApp.swift`, `CardsWatch/Services/WatchNavigation.swift`
**Notes:** iOS decides whether a notification shows on the iPhone or the watch. The simulator does not forward the iPhone's notifications to a paired watch, so a tap there is tried with a notification pushed to the watch simulator (docs/DEVELOPMENT.md, section 6).
