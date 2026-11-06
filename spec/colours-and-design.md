# Colours and design

How cards look: the palette, custom colours, the card face and its panels, full-colour list rows, the gradient, readable text, light and dark appearance, and the app icon. The rules behind them are in [docs/STYLE.md](../docs/STYLE.md).

### COL-1: Give a card a colour from the palette

As a card holder, I want to give each card a colour, so that I can spot the right one at a glance.

- The edit form's Colour section shows the palette as round swatches, six to a row, with the custom colour well in the last cell (COL-2).
- The palette has 23 colours, by hue and then the neutrals: Default, Red, Coral, Orange, Yellow, Lime, Green, Olive, Mint, Teal, Sky, Blue, Indigo, Navy, Lavender, Purple, Pink, Rose, Maroon, Brown, Sand, Graphite, Black.
- A new card is Default, which follows the system appearance (COL-7). Default's swatch has a thin outline.
- The chosen swatch has a tick in the colour's ink and a ring round it. Choosing a colour plays a selection haptic.
- Each swatch is 34 points across with a 44 point touch area, and VoiceOver reads its name and whether it is selected (A11Y-4).
- The colour is saved with the card when the form is saved.

**Since:** 1.3
**Where:** `Cards/UI/Components/CardColorPicker.swift`, `Cards/Core/Models/CardColor.swift`, `Cards/UI/Theme/CardPalette.swift`, `CardsTests/CardColorTests.swift` (`displayNamesAreUnique`, `paletteFillsWholeRowsWithTheCustomWell`)

### COL-2: Give a card any colour I like

As a card holder, I want to pick a colour outside the palette, so that a card can match the real one.

- The last cell of the colour grid is the system colour well. It shows the card's colour, or white for Default, and opens the system colour picker.
- The picker has no opacity control. The chosen colour is converted to sRGB and saved as a custom colour.
- While a custom colour is chosen, the well has the selection ring, and no palette swatch has a tick.
- A custom colour is stored as "#RRGGBB" in the card's colour field, the same field palette colours use, so it syncs and exports like them (DATA-1, DATA-2).
- Text stays readable on any custom colour (COL-5).

**Since:** 1.3
**Where:** `Cards/UI/Components/CardColorPicker.swift:60-79`, `Cards/UI/Theme/CardPalette.swift:208-214`, `CardsTests/CardColorTests.swift` (`pickedColourBecomesCustom`, `customColoursAreStoredAsHex`)

### COL-3: See the card face in the card's colour

As a card holder, I want the card screen to look like the card, so that I know I have opened the right one.

- The card face fills with the card's gradient (COL-6), with rounded corners of 28 points and a soft shadow. The card face is the only thing with a shadow.
- The name, the distance, the number and the date sit on white panels, inset 12 points from the card's edge and 12 points apart, with corners of 16 points so they nest inside the card's.
- The barcode's frame lines up with the panels: a 6 point translucent grey frame round white with corners of 10 points.
- Panel text is near-black (#1C1C1E). Supporting text, the distance and the date, is the same ink at 70%.
- The panels and the barcode's white stay white in dark mode.
- A Default card's face is a translucent grey over the screen's background.

**Since:** 1.3
**Where:** `Cards/UI/Screens/CardDetailView.swift`, `Cards/UI/Theme/CardGeometry.swift`, `Cards/UI/Theme/CardPalette.swift:29-37`, `CardsTests/CardColorTests.swift` (`CardGeometryTests`, `panelTextIsReadable`)

### COL-4: See each card in its full colour in the list

As a card holder, I want the list to show each card's colour at full strength, so that the list looks like my cards.

- Each row is a rounded rectangle, with corners of 18 points, filled with the card's gradient.
- The card's name sits straight on the colour, in the colour's ink (COL-5).
- The distance sits on a white pill in dark ink.
- A Default row uses the secondary system background, with the name in the system's text colour.
- The colour is never faded or tinted down in the list.
- In preparation for 1.4: the grid's tiles take the same fill, the name the same ink and the distance a white panel, with the card face's 28 point corners and a panel whose 16 point corners nest inside them (CARD-10).

**Since:** 1.3
**Where:** `Cards/UI/Screens/CardListView.swift`, `Cards/UI/Components/CardTileView.swift:30-70`, `Cards/UI/Theme/CardPalette.swift:196-206`, `CardsTests/CardColorTests.swift` (`textOnTheColourIsReadable`)
**Notes:** Before 1.3 the list rows were plain text with no colour.

### COL-5: Read text on any card colour

As a card holder, I want text on a card's colour to stay readable whatever colour I pick, so that a bold colour never hides a name.

- Text drawn straight on a colour uses that colour's ink: white or #1C1C1E, whichever has more contrast with it.
- That ink meets WCAG AA, a contrast of 4.5:1, on every palette colour as it is.
- A colour on which neither ink reaches 4.5:1, such as a mid grey, is moved away from the ink, towards black or white, in 2% steps until it does. Palette colours are never moved.
- The ink also meets 4.5:1 at both ends of the gradient (COL-6), for the palette, a sweep of 216 custom colours and the mid greys.
- Text on white panels, near-black and the same ink at 70%, meets 4.5:1.
- The pink accent used for buttons and links meets 4.5:1 on white in light mode (#D81B60) and on black in dark mode (#FF6699).

**Since:** 1.3
**Where:** `Cards/UI/Theme/CardPalette.swift`, `Cards/UI/Theme/Colors.swift`, `CardsTests/CardColorTests.swift`

### COL-6: See the same gradient wherever a card appears

As a card holder, I want a card to look the same in the list, on the card screen and in the widget, so that I learn its look.

- Card faces, list rows, the widget's background and the colour swatches all fill with the card's gradient. Nothing else in the app has one.
- The gradient is lighter at the top. For a colour with white ink, the top is the colour, moved if COL-5 needs it, and the bottom is 22% of the way from there to black. For a colour with dark ink, the bottom is the colour, moved if COL-5 needs it, and the top is 18% of the way from there to white.
- Default has no gradient: a translucent grey on the card face and swatch, the secondary system background in the list, and the system background in the widget.

**Since:** 1.3
**Where:** `Cards/UI/Theme/CardPalette.swift:168-200`, `CardsTests/CardColorTests.swift` (`standardFollowsTheSystemAppearance`, `textOnTheColourIsReadable`)

### COL-7: Use the app in light or dark mode

As a card holder, I want the app to follow my phone's appearance, so that it is comfortable to use at night.

- Screens use the system's backgrounds and text colours, so they follow light and dark mode.
- Buttons, links, the tab bar and the map's pin and radius ring use the pink accent, in a deeper shade in light mode (COL-5).
- Palette and custom colours, panels and barcodes look the same in both modes. Default follows the mode.

**Since:** 1.0
**Where:** `Cards/UI/Theme/Colors.swift`, `Cards/App/CardsApp.swift`

### COL-8: Keep a card's colour across versions

As a person with several devices, I want a card's colour to survive updates and older copies of the app, so that a card never loses its colour.

- Each palette colour is stored by a fixed name such as "blue". The names never change.
- The names of the first, 12-colour palette from the 1.2 test builds still read as the same colours.
- A colour the app doesn't recognise, such as a name from a newer build or a malformed "#12345", reads as Default.
- Builds from before custom colours show a custom colour as Default.
- Cards and exports from before colours existed read as Default (DATA-4).

**Since:** 1.3
**Where:** `Cards/Core/Models/CardColor.swift`, `CardsTests/CardColorTests.swift` (`storedValuesRoundTrip`, `earlierPaletteNamesStillMatch`, `unknownStoredValueFallsBackToStandard`), `CardsTests/CardItemTests.swift`

### COL-9: Recognise the app on my Home Screen

As a card holder, I want the app's icon to fit my Home Screen style, so that it is easy to find.

- The icon is a barcode card behind a QR code card, in monochrome (1.3).
- It has light, dark and tinted versions, which iOS picks to match the Home Screen.

**Since:** 1.0
**Where:** `Cards/Assets.xcassets/AppIcon.appiconset`, `DesignAssets/Icon.svg`, `scripts/generate-app-icons.ts`
**Notes:** 1.0 and 1.1 had a pink viewfinder icon, with dark and tinted versions since 1.0.
