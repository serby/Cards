# Cards

Keeping cards: the list, adding them by scanning or typing, opening one, editing, deleting, reordering and naming them.

### CARD-1: See all my cards in one list

As a card holder, I want all my cards in one list, so that I can find the one I need quickly.

- The Cards tab opens on a list titled "Cards", with one row per card in the order the cards are saved in (each card's `order`).
- Each row shows the card's name, filled with the card's colour (COL-4), and the distance to the nearest of its places when the card has places and the app knows where you are (PLACE-6).
- Tapping a row opens the card (CARD-4) with a heavy haptic tap.
- The navigation bar, with its add button, hides when the list scrolls down from the top, and comes back when the list is at the top again.
- With no cards, the list shows "No Cards Yet", "Scan the barcode on a loyalty card to add it." and an "Add Card" button that opens the add form (1.3).
- At the accessibility text sizes, a row stacks the name above the distance (A11Y-3).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardListView.swift`, `Cards/Features/CardListScreen.swift`, `CardsUITests/CardsScreenshotTests.swift`

### CARD-2: Add a card by scanning its barcode

As a card holder, I want to point the camera at a card's barcode, so that I don't have to type its number.

- The barcode viewfinder button at the top right of the list, labelled "Add Card" for VoiceOver, opens a form titled "Add Card" with the camera above the fields.
- The camera view is 250 points high, with rounded corners and a red line across the middle.
- The camera reads the nine supported types (BAR-1). On the first read it stops, the phone vibrates, and the form's code and barcode type fill in. The name stays as it was.
- After a read the camera stays stopped until the scanner view appears again.
- Pinching the camera view zooms from wherever the last pinch left off, within the camera's range and never past 8x (1.3).
- The first time, the form asks for the camera before it starts it, and iOS shows "Camera is used to scan barcodes on your loyalty and membership cards". The camera area is black until you answer.
- When camera access is refused or restricted, the camera area says "Camera access is off" and "Turn it on in Settings to scan a card, or type the code below.", with an Open Settings button that opens the app's page in the Settings app (1.3).
- On a device with no camera, such as the simulator, it says "No camera" and "Type the card's code below." (1.3).
- Both messages sit on a panel the colour of the form's rows, so it stands out in light and dark mode (1.3).
- The message fills the same rounded 250 point area, so the box is never left black. The code can still be typed (CARD-3).
- Saving adds the card and opens it (CARD-3).

**Since:** 1.0
**Where:** `Cards/Scanner/CameraScannerView.swift`, `Cards/Scanner/ScannerViewControllerDelegate.swift`, `Cards/UI/Components/CameraUnavailableView.swift`, `Cards/UI/Screens/CardEditView.swift`, `Cards/Features/CardEditScreen.swift`, `Info.plist`
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
**Where:** `Cards/UI/Screens/CardEditView.swift`, `Cards/Features/CardEditScreen.swift`, `Cards/UI/ViewState/CardViewState.swift`, `Cards/Features/CardListScreen.swift:88-103`, `Cards/Core/Models/CardImport.swift`, `CardsUITests/CardsUITests.swift` (`testAdd`), `CardsTests/CardFixesTests.swift` (`aCardNeedsANameAndACodeOfItsOwn`, `newCardsGoAtTheEnd`)
**Notes:** Before 1.3 Save was always enabled, and a new card was saved with `order` 0 and so landed among the cards at the top of the list.

### CARD-4: Open a card to show it

As a card holder, I want to open a card and see its barcode and number, so that it can be scanned or typed in at the till.

- The card screen shows the card face in the card's colour (COL-3): the name on a white panel at the top, the barcode in its frame (BAR-2), and the number and the date the card was added on a white panel below.
- When the card has places and the app knows where you are, the top panel also says how far away the nearest is, as "At Westway" or "350 m · Westway" (PLACE-6) (1.3).
- The number is in a monospaced font, and it can be selected and copied (1.3).
- A copy button beside the number puts it on the clipboard, for typing it into a website or another app. The icon turns into a tick for about a second and a half, and a success haptic plays. The number stays centred on its panel (1.3).
- The date shows the abbreviated date and the time, such as "4 Nov 2026 at 09:41".
- The toolbar has the brightness button (BAR-4) and Edit (CARD-5).
- Below the card, "Add current location" opens the map to add a place (PLACE-4) (1.3).
- Opening a card raises the screen brightness when Brightness Boost is on (BAR-4).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardDetailView.swift`, `Cards/Features/CardDetailScreen.swift`, `Cards/UI/Actions/CardActions.swift`, `CardsUITests/CardsUITests.swift` (`testAdd`, `testCopyCardCode`), `CardsUITests/CardsScreenshotTests.swift`

### CARD-5: Edit a card

As a card holder, I want to change a card's details, so that I can fix a mistake or keep it up to date.

- Edit on the card screen opens a form titled "Edit Card" with the card's name, code, barcode type, colour and places, and its Notify When I Arrive switch when it has places (ARR-6). There is no camera.
- The Name field takes the keyboard focus on its own after about 0.6 seconds, once. Coming back to the form from another tab leaves the keyboard down (1.3).
- Scrolling the form puts the keyboard away (1.3).
- Save follows the same rules as adding: it is disabled without a name and a code, or while another card uses the code, and it trims both (CARD-3, CARD-9) (1.3).
- Save writes every field to the card and shows the card screen; going back from there returns to the list.
- Going back from the form without saving discards every change, including places added or removed in it.
- A card can't be deleted from the form (CARD-6).

**Since:** 1.0
**Where:** `Cards/Features/CardEditScreen.swift`, `Cards/UI/Screens/CardEditView.swift`, `Cards/UI/ViewState/CardViewState.swift`, `Cards/Core/Navigation/NavigationManager.swift`
**Notes:** Links, the widget's chosen card and arrival notifications find a card by its code (CARD-8), so changing the code changes which card they point at. A widget set to the old code goes back to showing the nearest card (WID-2).

### CARD-6: Delete a card

As a card holder, I want to delete a card I no longer use, so that the list only holds cards I need.

- Swiping a row to the left offers Delete. Deleting asks for no confirmation.
- Deleting plays a medium haptic tap and renumbers the remaining cards in their order.
- With iCloud, the card is deleted on every device (DATA-1).
- The card's arrival notifications are cancelled (ARR-1) and the widget stops offering it (WID-7).
- Every card can be deleted at once from Settings (DATA-5).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardListView.swift`, `Cards/Features/CardListScreen.swift:112-123`

### CARD-7: Put my cards in the order I want

As a card holder, I want to move cards up and down the list, so that the ones I use most are at the top.

- A card can be moved to a new position in the list (`ForEach.onMove`). There is no Edit button on the list.
- After a move every card is renumbered from 0 in its new order and saved, so the order syncs with the cards (DATA-1).
- The top card is the one the widget shows when it can't pick a nearest card (WID-1).
- New cards, added in the form or imported, go at the end of the list (CARD-3, DATA-3) (1.3).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardListView.swift`, `Cards/Features/CardListScreen.swift:125-136`, `Cards/Core/Models/CardImport.swift`, `CardsTests/CardFixesTests.swift` (`newCardsGoAtTheEnd`)

### CARD-8: Tell my cards apart by name

As a card holder, I want each card to carry a name I choose, so that I know which card is which.

- A name is free text. It labels the card's row in the list, heads the card screen, and is the title of the widget and of the arrival notification.
- Names don't need to be unique.
- The form won't save a card without a name (CARD-3) (1.3). A card can still have an empty name if it was imported with one (DATA-3) or saved before 1.3.
- Inside the app a card is identified by its code: the list rows, links (NAV-2), the widget's choice of card (WID-2) and arrival notifications all use it. That is why codes are unique (CARD-9).

**Since:** 1.0
**Where:** `Cards/Core/Models/CardItem.swift`, `Cards/UI/ViewState/CardViewState.swift`, `Cards/Features/CardListScreen.swift:108-110`

### CARD-9: Keep each card's code its own

As a card holder, I want no two cards to share a code, so that links, the widget and notifications always open the card I mean.

- The add and edit forms won't save a code that another card uses. Save stays disabled, and "Another card already uses this code." shows under the Code field with an exclamation mark, until the code is changed to one no other card uses (CARD-3, CARD-5).
- The code is trimmed before it is compared, and otherwise has to match exactly, so the same letters in a different case are a different code.
- A card's own code doesn't count against it, so a card can be edited and saved without changing its code.
- A scanned code is checked in the same way as a typed one (CARD-2).
- Import skips a card whose code is already in the app, or earlier in the same text (DATA-3).

**Since:** 1.3
**Where:** `Cards/UI/ViewState/CardViewState.swift`, `Cards/UI/Screens/CardEditView.swift:84-90`, `Cards/Features/CardEditScreen.swift:85-91`, `Cards/Core/Models/CardImport.swift`, `CardsTests/CardFixesTests.swift` (`aCardNeedsANameAndACodeOfItsOwn`, `importSkipsCardsAlreadyThereAndAppendsInExportedOrder`)
**Notes:** Cards that shared a code before 1.3, or that were given the same code on two devices before they synced (DATA-1), still share it. Opening or linking to either then finds the first in the list, the list's rows share an identity, and the edit form won't save the card until its code is changed (`Cards/Features/CardListScreen.swift:106-108`, `Cards/UI/Screens/CardListView.swift:67`).
