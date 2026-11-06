# Sharing

Sending a card to someone else, as a link they can add to their own Card Barcodes or as a picture.

### SHARE-1: Share a card as a link

As a card holder, I want to send a card to someone, so that they can add it to their own phone without typing it in.

- The card screen's toolbar has a share button at the top right. It opens a menu with "Share Link" and "Share Image" (SHARE-2).
- Share Link opens the share sheet with a link to `https://cards.serby.net/add#…`. The part after `#` holds the whole card: its name, code, barcode type, colour, symbol (CARD-12), places (PLACE-1) and arrival switch (ARR-6).
- The card travels in the part after `#`, which browsers never send to a server, so the card's code does not reach cards.serby.net.
- On a phone with Card Barcodes, opening the link opens the app (SHARE-3). Without it, the link opens a page on cards.serby.net that explains what was shared and links to the App Store.

**Since:** In preparation for 1.4
**Where:** `Cards/UI/Screens/CardDetailView.swift`, `Cards/Features/CardDetailScreen.swift`, `Cards/Core/Navigation/NavigationRoute.swift`, `Website/src/add.html`

### SHARE-2: Share a card as an image

As a card holder, I want to send a picture of a card, so that someone can scan it from their own screen or keep it without the app.

- Share Image opens the share sheet with a PNG of the card face: its colour, name, symbol, barcode and number in text, as on the card screen (CARD-4), on its own without the toolbar or the rest of the screen.
- The image is drawn at three times screen scale, so the barcode stays sharp enough to scan when shown on another screen (BAR-2).
- The share sheet can save the image to Photos, which asks for permission to add photos the first time.

**Since:** In preparation for 1.4
**Where:** `Cards/UI/Screens/CardDetailView.swift`, `Cards/Features/CardDetailScreen.swift`

### SHARE-3: Add a card someone shared with me

As a card holder, I want to look at a card someone sent me before I add it, so that I only keep the cards I want.

- Opening a share link (SHARE-1) brings Card Barcodes forward on the Cards tab (NAV-1) and shows a sheet titled "Add Card?" with the card's face, name, barcode and places.
- "Add Card" adds it at the end of the list (CARD-3), then opens it. "Cancel" adds nothing.
- If a card with the same code is already in the app, the sheet says "You already have this card." and offers "Open Card" instead of Add, because codes are unique (CARD-9).
- A link whose card cannot be read shows "This link doesn't contain a card." and adds nothing.

**Since:** In preparation for 1.4
**Where:** `Cards/Features/CardListScreen.swift`, `Cards/Core/Navigation/NavigationRoute.swift`, `Cards/App/CardsApp.swift`
**Notes:** Opening the link in the app needs cards.serby.net to serve an `apple-app-site-association` file for the app, and the app to have the Associated Domains capability for `applinks:cards.serby.net`.
