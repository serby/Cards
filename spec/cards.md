# Cards

Keeping cards: the list, adding them by scanning, typing or from a photo or a file, opening one, editing, deleting, reordering and naming them.

### CARD-1: See all my cards in one list

As a card holder, I want all my cards in one list, so that I can find the one I need quickly.

- The Cards tab opens on a list titled "Cards", with one row per card in the order the cards are saved in (each card's `order`).
- Each row shows the card's name, filled with the card's colour (COL-4), and the distance to the nearest of its places when the card has places and the app knows where you are (PLACE-6).
- Tapping a row opens the card (CARD-4) with a heavy haptic tap.
- In preparation for 1.4: the list becomes a grid of tiles (CARD-10), with search and a choice of order (CARD-11), and opening a card plays no haptic (A11Y-5).
- The navigation bar, with its add button, hides when the list scrolls down from the top, and comes back when the list is at the top again. In preparation for 1.4: the grid does the same, and the bar stays while you search (CARD-11).
- With no cards, the list shows "No Cards Yet", "Scan the barcode on a loyalty card to add it." and an "Add Card" button that opens the add form (1.3).
- At the accessibility text sizes, a row stacks the name above the distance (A11Y-3). In preparation for 1.4: the grid has half as many columns instead (CARD-10).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardListView.swift`, `Cards/UI/Components/CardTileView.swift`, `Cards/Features/CardListScreen.swift`, `CardsUITests/CardsScreenshotTests.swift`

### CARD-2: Add a card by scanning its barcode

As a card holder, I want to point the camera at a card's barcode, so that I don't have to type its number.

- The barcode viewfinder button at the top right of the list, labelled "Add Card" for VoiceOver, opens a form titled "Add Card" with the camera above the fields.
- The camera view is 250 points high, with rounded corners and a red line across the middle.
- In preparation for 1.4: the camera focuses on a card held close (BAR-5).
- The camera reads the nine supported types (BAR-1). On the first read it stops, the phone vibrates, and the form's code and barcode type fill in. The name stays as it was.
- After a read the camera stays stopped until the scanner view appears again.
- Pinching the camera view zooms from wherever the last pinch left off, within the camera's range and never past 8x (1.3). In preparation for 1.4: the range runs from the main lens's own view, never out to the ultra-wide, to 8x the main lens, and the zoom starts where BAR-5 puts it.
- The first time, the form asks for the camera before it starts it, and iOS shows "Camera is used to scan barcodes on your loyalty and membership cards". The camera area is black until you answer.
- When camera access is refused or restricted, the camera area says "Camera access is off" and "Turn it on in Settings to scan a card, or type the code below.", with an Open Settings button that opens the app's page in the Settings app (1.3).
- On a device with no camera, such as the simulator, it says "No camera" and "Type the card's code below." (1.3).
- Both messages sit on a panel the colour of the form's rows, so it stands out in light and dark mode (1.3).
- The message fills the same rounded 250 point area, so the box is never left black. The code can still be typed (CARD-3).
- Saving adds the card and opens it (CARD-3).

**Since:** 1.0
**Where:** `Cards/Scanner/CameraScannerView.swift`, `Cards/Scanner/ScannerViewControllerDelegate.swift`, `Cards/Scanner/ScannerModel.swift`, `Cards/Scanner/CameraSession.swift`, `Cards/UI/Components/CameraUnavailableView.swift`, `Cards/UI/Screens/CardEditView.swift`, `Cards/Features/CardEditScreen.swift`, `Info.plist`
**Notes:** Only the add form has the camera. Editing a card has no scanner, so a card's code can only be changed by typing. In 1.0 scanning was a separate screen; since 1.1 the camera sits in the add form behind a single add button.

### CARD-3: Add a card by typing its number

As a card holder, I want to type a card's number in, so that I can keep a card the camera can't read.

- The add form has a Name field ("Enter name"), a Code field ("Enter code"), a Barcode Type menu, a Colour section (COL-1) and a Locations section (PLACE-1). Colour and Locations are 1.3.
- Both fields have autocorrection off. The Code field uses the standard keyboard, so codes can hold letters and symbols.
- The barcode type defaults to Code 128.
- Save is disabled until both the name and the code have something in them other than spaces, and while another card uses the code (CARD-9) (1.3).
- Saving trims spaces and new lines from both ends of the name and the code (1.3).
- Saving adds the card at the end of the list and opens its card screen (1.3).
- There is no Cancel button. Going back from the form discards it and adds nothing.
- Scrolling the form puts the keyboard away (1.3).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardEditView.swift`, `Cards/Features/CardEditScreen.swift`, `Cards/UI/ViewState/CardViewState.swift`, `Cards/Features/CardListScreen.swift`, `Cards/Core/Models/CardImport.swift`, `CardsUITests/CardsUITests.swift` (`testAdd`), `CardsTests/CardFixesTests.swift` (`aCardNeedsANameAndACodeOfItsOwn`, `newCardsGoAtTheEnd`)
**Notes:** Before 1.3 Save was always enabled, and a new card was saved with `order` 0 and so landed among the cards at the top of the list.

### CARD-13: Add a card from a photo or a file of its barcode

As a card holder, I want to add a card from a screenshot, a photo or a PDF of its barcode, so that I can keep a card I only have as a picture or an e-ticket.

- The add form has Choose Photo and Choose File under the camera (CARD-2), with the caption "Read the barcode in a screenshot, a photo or a PDF, such as an e-ticket." Editing a card offers neither.
- Choose Photo opens the system photo picker, showing pictures only. The app sees only the photo chosen and never asks for access to the photo library.
- Choose File opens the Files picker for images and PDFs. A file from outside the app is read inside its security-scoped access.
- While a photo or file is read, both buttons are disabled and "Reading the barcode…" shows under them with a spinner.
- The app reads the nine supported types (BAR-1), top to bottom in a picture, and page by page in a PDF. A photo is read the right way up and at most 4,096 pixels on its longer side. A PDF's pages are drawn on white at 288 dots per inch, at most 4,096 pixels on the longer side, so a barcode 5 cm wide on an A4 page reads; only the first 20 pages are read.
- One barcode fills in the form's code and barcode type, as a scan does. The name stays as it was. The phone plays a success haptic, and VoiceOver announces "Barcode found: QR Code. Its code is filled in." with the type found.
- Several barcodes, such as a ticket with a QR code and a strip barcode, open a sheet titled "Choose a Barcode". It lists each barcode once, in the order found, with its type above its code, and says "2 barcodes found. Choose the one for this card." Tapping one fills it in as above and closes the sheet; Cancel closes it and fills in nothing. A code that appears twice, such as on two pages, is listed once.
- A barcode the app can show is always offered over one it cannot, so a ticket with a QR code and a Data Matrix code fills in the QR code.
- When nothing can be filled in, a message under the buttons says why, and VoiceOver announces it:
  - no barcode: "No barcode found. Try a picture where the whole barcode is sharp.";
  - only kinds the app cannot show, such as Data Matrix or ITF-14: "Card Barcodes cannot show Data Matrix codes.", naming each kind found, or "Card Barcodes cannot show this kind of barcode." for a kind it has no name for;
  - a photo or file that cannot be opened, is neither a picture nor a PDF, or that Vision cannot look at: "That photo or file could not be read."
- The message stays until the next photo or file is read. Choosing the same photo again reads it again.
- In the sheet, each barcode reads as its type, then its code character by character, with the hint "Fills in this code and type".
- The photo or file is read on the device by Apple's Vision framework, and is not kept or sent anywhere.
- This is separate from Import Cards in Settings, which adds cards from an exported JSON file (DATA-3).

**Since:** In preparation for 1.4
**Where:** `Cards/UI/Components/BarcodeImportSection.swift`, `Cards/UI/Components/BarcodeChoiceList.swift`, `Cards/UI/ViewState/BarcodeImportStatus.swift`, `Cards/Core/Models/BarcodeReading.swift`, `Cards/Core/Services/BarcodeImageReader.swift`, `Cards/Core/Services/FileReader.swift`, `Cards/UI/Screens/CardEditView.swift`, `Cards/Features/CardEditScreen.swift`, `CardsTests/BarcodeImageReaderTests.swift`, `CardsUITests/CardsUITests.swift` (`testAddFormOffersAPhotoOrAFile`)
**Notes:** Vision cannot make its barcode detector in the simulator ("Failed to create barcode detector." on iOS 18.1 and 27.0), so there every photo or file says it could not be read. The tests that read through Vision run only on a device; the simulator, and CI, test how pictures and pages are prepared and what is done with what Vision finds.

### CARD-4: Open a card to show it

As a card holder, I want to open a card and see its barcode and number, so that it can be scanned or typed in at the till.

- The card screen shows the card face in the card's colour (COL-3): the name on a white panel at the top, the barcode in its frame (BAR-2), and the number and the date the card was added on a white panel below.
- In preparation for 1.4: the card's symbol, if it has one, sits beside the name in the top panel (CARD-12).
- When the card has places and the app knows where you are, the top panel also says how far away the nearest is, as "At Boulder Barn" or "350 m · Boulder Barn" (PLACE-6) (1.3).
- In preparation for 1.4: when the card has more than one place, a panel at the foot of the card face lists the nearest five with their distances, and a place opens in Maps (PLACE-9). The screen scrolls when the card is taller than it.
- The number is in a monospaced font, and it can be selected and copied (1.3).
- A copy button beside the number puts it on the clipboard, for typing it into a website or another app. The icon turns into a tick for about a second and a half, and a success haptic plays. The number stays centred on its panel (1.3).
- The date shows the abbreviated date and the time, such as "4 Nov 2026 at 09:41".
- The toolbar has the brightness button (BAR-4) and Edit (CARD-5). In preparation for 1.4 a share button comes first, to their left (SHARE-1).
- Below the card, "Add current location" opens the map to add a place (PLACE-4) (1.3).
- Opening a card raises the screen brightness when Brightness Boost is on (BAR-4).
- In preparation for 1.4: opening a card records when it was last viewed, for the Last viewed order (CARD-11). Coming back to the card from its edit form counts as opening it again.

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardDetailView.swift`, `Cards/Features/CardDetailScreen.swift`, `Cards/UI/Actions/CardActions.swift`, `CardsUITests/CardsUITests.swift` (`testAdd`, `testCopyCardCode`), `CardsUITests/CardsScreenshotTests.swift`

### CARD-5: Edit a card

As a card holder, I want to change a card's details, so that I can fix a mistake or keep it up to date.

- Edit on the card screen opens a form titled "Edit Card" with the card's name, code, barcode type, colour and places, and its Notify When I Arrive switch when it has places (ARR-6). There is no camera. In preparation for 1.4 the form also has the card's symbol (CARD-12).
- The Name field takes the keyboard focus on its own after about 0.6 seconds, once. Coming back to the form from another tab leaves the keyboard down (1.3).
- Scrolling the form puts the keyboard away (1.3).
- Save follows the same rules as adding: it is disabled without a name and a code, or while another card uses the code, and it trims both (CARD-3, CARD-9) (1.3).
- Save writes every field to the card and shows the card screen; going back from there returns to the list.
- Going back from the form without saving discards every change, including places added or removed in it.
- A card can't be deleted from the form (CARD-6). In preparation for 1.4 it can: Delete Card at the foot of the edit form asks "Delete Joe's Market?", saying it is deleted from all your devices and cannot be undone, then deletes the card and goes back to the list. Adding a card has no Delete Card.

**Since:** 1.0
**Where:** `Cards/Features/CardEditScreen.swift`, `Cards/UI/Screens/CardEditView.swift`, `Cards/UI/ViewState/CardViewState.swift`, `Cards/Core/Navigation/NavigationManager.swift`, `Cards/UI/Actions/CardActions.swift`, `CardsUITests/CardsUITests.swift` (`testDeleteFromTheEditForm`)
**Notes:** Links, the widget's chosen card and arrival notifications find a card by its code (CARD-8), so changing the code changes which card they point at. A widget set to the old code goes back to showing the nearest card (WID-2).

### CARD-6: Delete a card

As a card holder, I want to delete a card I no longer use, so that the list only holds cards I need.

- Swiping a row to the left offers Delete. Deleting asks for no confirmation.
- Deleting plays a medium haptic tap and renumbers the remaining cards in their order.
- With iCloud, the card is deleted on every device (DATA-1).
- The card's arrival notifications are cancelled (ARR-1) and the widget stops offering it (WID-7).
- Every card can be deleted at once from Settings (DATA-5).
- In preparation for 1.4: Delete Card at the foot of the edit form deletes the card too, after asking, and goes back to the list (CARD-5).
- In preparation for 1.4: the grid has no swipe actions, so Delete moves to the menu a long press on a tile shows (CARD-10). It deletes the card at once, with the same medium haptic, and the remaining cards are renumbered from 0 in their order. VoiceOver offers Delete as an action on the tile (A11Y-1).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardListView.swift`, `Cards/UI/Components/CardTileView.swift`, `Cards/Features/CardListScreen.swift`, `CardsUITests/CardsUITests.swift` (`testDeleteFromTheLongPressMenu`), `Cards/Features/CardEditScreen.swift`, `Cards/Core/Models/CardImport.swift` (`renumber`), `CardsUITests/CardsUITests.swift` (`testDeleteFromTheEditForm`)

### CARD-7: Put my cards in the order I want

As a card holder, I want to move cards up and down the list, so that the ones I use most are at the top.

- A card can be moved to a new position in the list (`ForEach.onMove`). There is no Edit button on the list.
- After a move every card is renumbered from 0 in its new order and saved, so the order syncs with the cards (DATA-1).
- The top card is the one the widget shows when it can't pick a nearest card (WID-1).
- New cards, added in the form or imported, go at the end of the list (CARD-3, DATA-3) (1.3).
- In preparation for 1.4: you press and hold a tile, then drag it onto another. It takes that tile's place, and the tiles between shift along by one. Every card is then renumbered and saved, as after a move in the list (CARD-10).
- In preparation for 1.4: tiles can only be dragged in custom order with nothing in the search field (CARD-11).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardListView.swift`, `Cards/Features/CardListScreen.swift`, `Cards/Core/Models/CardArrangement.swift`, `Cards/Core/Models/CardImport.swift`, `CardsTests/CardFixesTests.swift` (`newCardsGoAtTheEnd`), `CardsTests/CardArrangementTests.swift` (`aMovedCardTakesThePlaceOfTheOneItIsDroppedOn`), `CardsUITests/CardsUITests.swift` (`testDragATileToReorder`)

### CARD-8: Tell my cards apart by name

As a card holder, I want each card to carry a name I choose, so that I know which card is which.

- A name is free text. It labels the card's row in the list, heads the card screen, and is the title of the widget and of the arrival notification.
- Names don't need to be unique.
- The form won't save a card without a name (CARD-3) (1.3). A card can still have an empty name if it was imported with one (DATA-3) or saved before 1.3.
- Inside the app a card is identified by its code: the list rows, links (NAV-2), the widget's choice of card (WID-2) and arrival notifications all use it. That is why codes are unique (CARD-9).

**Since:** 1.0
**Where:** `Cards/Core/Models/CardItem.swift`, `Cards/UI/ViewState/CardViewState.swift`, `Cards/Features/CardListScreen.swift`

### CARD-9: Keep each card's code its own

As a card holder, I want no two cards to share a code, so that links, the widget and notifications always open the card I mean.

- The add and edit forms won't save a code that another card uses. Save stays disabled, and "Another card already uses this code." shows under the Code field with an exclamation mark, until the code is changed to one no other card uses (CARD-3, CARD-5).
- The code is trimmed before it is compared, and otherwise has to match exactly, so the same letters in a different case are a different code.
- A card's own code doesn't count against it, so a card can be edited and saved without changing its code.
- A scanned code is checked in the same way as a typed one (CARD-2).
- Import skips a card whose code is already in the app, or earlier in the same text (DATA-3).

**Since:** 1.3
**Where:** `Cards/UI/ViewState/CardViewState.swift`, `Cards/UI/Screens/CardEditView.swift`, `Cards/Features/CardEditScreen.swift`, `Cards/Core/Models/CardImport.swift`, `CardsTests/CardFixesTests.swift` (`aCardNeedsANameAndACodeOfItsOwn`, `importSkipsCardsAlreadyThereAndAppendsInExportedOrder`)
**Notes:** Cards that shared a code before 1.3, or that were given the same code on two devices before they synced (DATA-1), still share it. Opening or linking to either then finds the first in the list, the list's rows share an identity, and the edit form won't save the card until its code is changed (`Cards/Features/CardListScreen.swift`, `Cards/UI/Screens/CardListView.swift`).

### CARD-10: See my cards in a grid

As a card holder, I want my cards laid out in a grid, so that I can see more of them at once and pick one quickly.

- The Cards tab shows the cards as tiles in a grid: two columns on iPhone, and four where the screen is wide (an iPad, unless the app has a narrow part of the screen beside another app, when it has two). The order runs left to right, then on to the next row.
- At the accessibility text sizes the grid has half as many columns, one on iPhone and two on iPad, so names have room (A11Y-3).
- Each tile is filled with the card's colour at full strength, in its gradient (COL-4), with the card face's rounded corners. Along the top are its symbol on the left, if it has one (CARD-12), and on the right how far away its nearest place is, on a white panel whose corners nest inside the tile's (PLACE-6). Its name, in the colour's ink, is at the bottom.
- A tile is at least 112 points high, growing with the text size up to 200 points, and names wrap rather than being cut short. The tiles in a row are as tall as the tallest.
- Tapping a tile opens the card (CARD-4). Opening a card plays no haptic (A11Y-5).
- A long press on a tile lifts it and shows a menu with Delete, and the system plays its haptic as the menu appears. Delete removes the card at once, with the medium haptic swiping had in the list (CARD-6).
- In custom order (CARD-11), you press and hold a tile and drag it onto another to reorder the cards (CARD-7). The tile under the dragged one is outlined in the accent colour. The new order is saved and syncs (DATA-1).
- When the cards change order, from a drag, a new sort order, a search or as you move, the tiles slide to their new places.
- VoiceOver reads each tile as one button, the name and then the distance, as the rows did (A11Y-1), and offers Delete as an action.
- The add button and the empty state stay as they are on the list.

**Since:** In preparation for 1.4
**Where:** `Cards/UI/Screens/CardListView.swift`, `Cards/UI/Components/CardTileView.swift`, `Cards/Features/CardListScreen.swift`, `Cards/Core/Models/CardArrangement.swift`, `CardsUITests/CardsUITests.swift` (`testDeleteFromTheLongPressMenu`, `testDragATileToReorder`), `CardsUITests/CardsScreenshotTests.swift`
**Notes:** It replaces the single-column list. A grid has no swipe actions, which is why Delete moved to the long-press menu. Dragging uses SwiftUI's drag and drop, which works from iOS 18, so the other tiles don't part to make a gap while you drag; they move when you let go.

### CARD-11: Find a card by searching and sorting

As a card holder, I want to search my cards and choose their order, so that the card I need is always easy to reach.

- The Cards tab has a search field, "Search", where iOS puts it: below the title on iPhone, which iOS 26 and later keep out of sight until you pull the grid down, and in the toolbar on iPad from iOS 26. Typing filters the grid to cards whose name contains the text, ignoring case and accents, spaces at either end, and whether apostrophes and quotes are curly, so "joe’s" finds "Joe's Market". Clearing or cancelling the search shows every card again.
- When nothing matches, the grid gives way to "No Cards Match" and "Check the spelling, or try another name."
- A sort menu, an up and down arrow labelled "Sort" beside the add button, offers three orders, with a tick by the chosen one:
  - **Last Viewed:** the card opened most recently comes first. Cards opened at the same moment, and then the cards never opened, follow in custom order.
  - **Custom Order:** the order you set by dragging (CARD-7, CARD-10), as before.
  - **Location:** cards with a place come first, by the distance to the edge of their nearest place (PLACE-6). Between places you are inside, the one whose middle you are nearer comes first, and equal distances keep custom order. Cards without places follow in custom order, and when the app does not know where you are every card is in custom order. Choosing it doesn't ask for location permission (PLACE-7). The order changes as you move.
- The search applies in every order.
- The chosen order is kept on the device, under `cardSortOrder`, and doesn't sync. It is still chosen the next time the app opens, and starts as custom order.
- Only custom order can be rearranged by dragging, and only with nothing in the search field.
- Opening a card records when it was last viewed. That date is stored with the card, so it syncs (DATA-1) and is exported (DATA-2).

**Since:** In preparation for 1.4
**Where:** `Cards/UI/Screens/CardListView.swift`, `Cards/Features/CardListScreen.swift`, `Cards/Core/Models/CardArrangement.swift`, `Cards/Core/Models/CardSortOrder.swift`, `Cards/Core/Models/DeviceSettings.swift`, `Cards/Core/Models/CardItem.swift`, `CardsTests/CardArrangementTests.swift`, `CardsUITests/CardsUITests.swift` (`testSearchFiltersCards`, `testSortMenuChangesTheOrder`), `Cards/Features/CardDetailScreen.swift`

### CARD-12: Give a card a symbol

As a card holder, I want each card to carry a symbol, so that I can recognise it at a glance.

- The add and edit forms have a Symbol row, below Colour, that shows the card's symbol, or "None", and opens a sheet titled "Symbol".
- The sheet is a grid of 35 symbols suited to cards, None first, then shopping (a basket, a trolley, a shopping bag, a price tag, a gift, a T-shirt), food and drink (a coffee cup, a mug, a takeaway, a restaurant, a cake, a wine glass), getting about (a fuel pump, a car, an aeroplane, a bus, a hotel, a suitcase), fitness (a dumbbell, running, swimming, climbing, a bicycle), health (first aid, a pharmacy, a heart), books and going out (a book, a library, a ticket, a cinema, a theatre) and pets, home and garden (pets, a garden, DIY, a hairdresser).
- Each symbol in the grid is drawn on the card's colour in the colour's ink, as the colour swatches are (COL-4), and the chosen one has a ring round it. Tapping one chooses it and closes the sheet; Done closes it without a change.
- The choice is saved with the card when the form is saved, like every other field (CARD-5). Going back without saving keeps the old symbol.
- A card has no symbol until you choose one. Older cards and older exports have none.
- The symbol shows at the top of the card's tile in the grid (CARD-10), in the colour's ink like the name, so it stays readable (COL-4).
- It shows on the card screen beside the name in the top panel (CARD-4), drawn in the panel's ink. At the accessibility text sizes it sits above the name instead (A11Y-3).
- VoiceOver does not read the symbol on the card or its tile, because the card's name already says what it is (A11Y-4). In the form, where you choose it, the Symbol row reads its value by what the symbol shows, such as "Basket", or "None", and so does each symbol in the grid.
- The symbol is stored with the card, so it syncs (DATA-1), is exported, and is imported with the card (DATA-2, DATA-3).

**Since:** In preparation for 1.4
**Where:** `Cards/Core/Models/CardSymbol.swift`, `Cards/UI/Components/CardSymbolPicker.swift`, `Cards/UI/Screens/CardEditView.swift`, `Cards/Features/CardEditScreen.swift`, `Cards/UI/Components/CardFaceView.swift`, `Cards/Features/CardDetailScreen.swift`, `Cards/Core/Models/CardItem.swift`, `Cards/UI/Screens/CardListView.swift`, `CardsTests/CardSymbolTests.swift`, `CardsUITests/CardsUITests.swift` (`testChooseASymbol`), `Cards/UI/Screens/CardDetailView.swift`, `Cards/UI/Components/CardTileView.swift`, `Cards/Features/CardListScreen.swift`
**Notes:** Every symbol is in SF Symbols 6, so iOS 18 draws it; `CardSymbolTests` checks each one on the oldest supported iOS. A symbol name the build doesn't list, such as one from a newer version, still shows on the card.
