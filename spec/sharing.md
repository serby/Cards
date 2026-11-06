# Sharing

Sending a card to someone else, as a link they can add to their own Card Barcodes or as a picture.

### SHARE-1: Share a card as a link

As a card holder, I want to send a card to someone, so that they can add it to their own phone without typing it in.

- The card screen's toolbar has a share button, the share icon, at the top right. Reading from the left, the toolbar is share, brightness (BAR-4) and Edit (CARD-5), so the brightness button and Edit stay where they were. VoiceOver reads it as "Share card".
- The share button opens a menu with "Share Link" and "Share Image" (SHARE-2).
- Share Link opens the share sheet with a link to `https://cards.serby.net/add#…`, titled with the card's name. The part after `#` holds the whole card: its name, code, barcode type, colour, symbol (CARD-12), places (PLACE-1) with their names, positions and radii, and arrival switch (ARR-6).
- The link carries nothing else: not when the card was added, where it sits in the list, or when it was last opened (CARD-11).
- The card travels in the part after `#`, which browsers never send to a server, so the card's code does not reach cards.serby.net.
- The same card always makes the same link.
- On a phone with Card Barcodes, opening the link opens the app (SHARE-3). Without it, the link opens a page on cards.serby.net titled "Someone shared a card with you" that shows the card's name, read from the part after `#` in the browser, says to open the link on an iPhone or iPad with Card Barcodes, and links to the App Store. A link without a readable card shows the page without a name.

**Since:** In preparation for 1.4
**Where:** `Cards/UI/Screens/CardDetailView.swift`, `Cards/Features/CardDetailScreen.swift`, `Cards/UI/ViewState/CardShare.swift`, `Cards/Core/Models/SharedCard.swift`, `Cards/Core/Navigation/SharedCardLink.swift`, `Website/src/add.html`, `Website/src/.well-known/apple-app-site-association`, `Website/src/_headers`, `Cards/Cards.entitlements`, `Cards/Cards.Debug.entitlements`, `CardsTests/SharingTests.swift`, `CardsUITests/CardSharingUITests.swift` (`testShareMenuOffersALinkAndAnImage`)
**Notes:** The part after `#` is a `SharedCard`, a small format of its own rather than the export's `CardItemDTO`, which carries the sharer's dates and order. It is JSON in base64url without padding, with the keys `v` (the format version, 1), `name`, `code`, `type`, `color`, `symbol` (left out when there is none), `places` (each `name`, `latitude`, `longitude` and `radius`, left out when there are none) and `notifiesOnArrival`.

### SHARE-2: Share a card as an image

As a card holder, I want to send a picture of a card, so that someone can scan it from their own screen or keep it without the app.

- Share Image opens the share sheet with a PNG of the card face: its colour, name, symbol, barcode, number in text and the date it was added, as on the card screen (CARD-4), on its own without the toolbar or the rest of the screen.
- The picture leaves out the copy button and how far away the card's places are, because where you are is not part of the card.
- It is always drawn in light appearance, 360 points wide at three times screen scale (1,080 pixels), so the barcode stays sharp enough to scan when shown on another screen (BAR-2). A card in the default colour sits on white.
- The file is called after the card, such as "Boots Advantage.png", with any "/", "\" or ":" in the name turned into "-", or "Card.png" when the name is empty.
- The picture is drawn only when the share sheet asks for it, so opening a card does no extra work.
- The share sheet offers Save Image, which saves the picture to Photos. The first time, iOS asks for permission to add photos, saying "Saves the picture of a card you share to your photos." The app never asks to read Photos.

**Since:** In preparation for 1.4
**Where:** `Cards/UI/Screens/CardDetailView.swift`, `Cards/Features/CardDetailScreen.swift`, `Cards/Features/CardShareImage.swift`, `Cards/UI/ViewState/CardShare.swift` (`CardImage`), `Info.plist` (`NSPhotoLibraryAddUsageDescription`), `CardsTests/SharingTests.swift` (`theSharedImageIsTheFaceAtThreeTimesScale`, `imageFileNamesComeFromTheCardsName`), `CardsUITests/CardSharingUITests.swift`

### SHARE-3: Add a card someone shared with me

As a card holder, I want to look at a card someone sent me before I add it, so that I only keep the cards I want.

- Opening a share link (SHARE-1), as `https://cards.serby.net/add#…` or as `cards://cards/add#…`, brings Card Barcodes forward on the Cards tab (NAV-1) and shows a sheet titled "Add Card?" with the card's face, name, symbol, barcode and number, and its places under "Locations" when it has any.
- The sheet opens over whatever the Cards tab was showing, which stays as it was, so Cancel goes back to it.
- The face shows no distance, and its date is when the sheet opened, which becomes the date the card was added.
- "Add Card", at the bottom, adds it by the import rules (DATA-3): at the end of the list (CARD-3), with its code and name trimmed and its places as new places of your own. Then the sheet closes on the new card's screen. "Cancel" adds nothing.
- If a card with the same code is already in the app, by the import rules' comparison of trimmed codes, the sheet says "You already have this card." and offers "Open Card" instead of Add, because codes are unique (CARD-9). Open Card closes the sheet on that card's screen. If the card arrives through iCloud while the sheet is open, Add Card opens it instead of adding a second.
- A link whose card cannot be read shows "This link doesn't contain a card." with a "Done" button, and adds nothing. That is a link with nothing after the `#`, text that is not a card, a card without a name or a code, a card in a newer format, or anything over 16,384 characters.
- Opening a card from anywhere else, such as a notification, closes the sheet.

**Since:** In preparation for 1.4
**Where:** `Cards/App/CardsApp.swift` (`onOpenURL`, `onContinueUserActivity`, the sheet), `Cards/Core/Navigation/NavigationManager.swift` (`sharedCard`, `show(_:)`, `handleDeepLink(_:)`), `Cards/Core/Navigation/SharedCardLink.swift`, `Cards/Core/Models/SharedCard.swift` (`importResult(existing:addedAt:)`), `Cards/Features/SharedCardScreen.swift`, `Cards/UI/Screens/SharedCardView.swift`, `Cards/UI/ViewState/SharedCardState.swift`, `CardsTests/SharingTests.swift`, `CardsTests/NavigationTests.swift` (`shareLinksShowTheCardOverTheCardsTab`, `openingACardClosesTheSharedCardSheet`), `CardsUITests/CardSharingUITests.swift` (`testAddACardFromAShareLink`, `testALinkWithoutACardSaysSo`)
**Notes:** Opening the https link in the app needs cards.serby.net to serve an `apple-app-site-association` file for the app, and the app to have the Associated Domains capability for `applinks:cards.serby.net`. The `cards://` form works without either, which is how the simulator and the UI tests open share links.
