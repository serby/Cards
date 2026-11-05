# Accessibility

How the app works with VoiceOver, larger text sizes and touch, and the feedback it gives. Accessibility is part of every story; this file collects what applies across them.

### A11Y-1: Hear my cards read clearly with VoiceOver

As someone using VoiceOver, I want every card read in plain words, so that I can find and show the right one.

- A list row reads as one button: the card's name, then its distance, as "Tesco Clubcard, You're at Tesco Express" or "Costa Coffee, 350 m from Costa Portobello" (1.3).
- The add button reads "Add Card".
- On the card screen, the name reads "Card name: <name>" and is a heading.
- The barcode reads "Barcode for <name>", with the hint "This is a <type> barcode with code <code>".
- The number reads "Card code: " and then the code character by character (1.3).
- The date reads "Created on <date>", with the full month, such as "Created on 4 November 2026 at 09:41".
- Edit reads "Edit card", with the hint "Tap to edit this card's details".
- The brightness button reads "Brightness Boost", with the hint "Toggles screen brightness to maximum for easier barcode scanning".
- "Add current location" has the hint "Opens a map to save where you are as one of this card's places" (1.3).
- In the edit form the fields read "Card name" and "Card code", the type menu "Barcode type", and Save "Save card".
- Save's hint is "Save changes to this card", or "Needs a name and a code no other card uses" while it is disabled (CARD-3, CARD-9) (1.3).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardListView.swift`, `Cards/UI/Screens/CardDetailView.swift`, `Cards/UI/Screens/CardEditView.swift`, `Cards/UI/Components/BarcodeView.swift`, `Cards/UI/Components/ProximityLabel.swift`, `CardsUITests/CardsUITests.swift`
**Notes:** The barcode's hint reads the code as one word, while the number below it is spelt out (`Cards/UI/Components/BarcodeView.swift:37`).

### A11Y-2: Hear when the brightness changes

As someone using VoiceOver, I want to be told when the app changes the screen brightness, so that a sudden change isn't a surprise.

- Opening a card with the boost on announces "Screen brightness increased for better barcode visibility".
- The brightness button announces "Brightness boost on" or "Brightness boost off" (BAR-4).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardDetailView.swift:94-157`, `Cards/UI/Environment/ScreenBrightness.swift:52-74`

### A11Y-3: Use the app at large text sizes

As a card holder who uses large text, I want the app to grow with my text size, so that I can read it.

- Text uses the system's text styles, so it follows Dynamic Type throughout.
- At the accessibility text sizes, a list row stacks the name above the distance (1.3).
- The location sheet's fields are at least 44 points high and grow with the text (1.3).
- Distances never wrap: they stay on one line (PLACE-6).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardListView.swift:45-50`, `Cards/UI/Screens/LocationPickerView.swift:231-245`, `Cards/UI/Components/ProximityLabel.swift`

### A11Y-4: Use every control with VoiceOver and touch

As someone using VoiceOver, I want every control labelled and every image that adds nothing kept quiet, so that I hear only what matters.

- Colour swatches read their name, such as "Teal", and "Selected" for the chosen one. The grid reads as "Card colour" (1.3).
- Each swatch, and the custom colour well, has a 44 point touch area (1.3).
- A place in the edit form reads as one item: its name and radius (1.3).
- The radius slider reads "Radius" with its value, such as "200 m" (1.3).
- The map's pin and ring, the place icons, the field icons in the location sheet and the tick on a swatch are hidden from VoiceOver (1.3).
- The external link icon in Settings reads "External link" (1.1).
- When the camera can't be used, its title and text read as one item, such as "No camera, Type the card's code below.", Open Settings is a separate button, and the icon is hidden (CARD-2) (1.3).
- The widget reads as one item with a hint, and its barcode image is hidden (WID-5).

**Since:** 1.0
**Where:** `Cards/UI/Components/CardColorPicker.swift`, `Cards/UI/Components/CardLocationRow.swift`, `Cards/UI/Screens/LocationPickerView.swift`, `Cards/UI/Screens/SettingsListView.swift`, `Cards/UI/Components/CameraUnavailableView.swift`, `Cards/UI/Components/CardWidgetView.swift`

### A11Y-5: Feel that something happened

As a card holder, I want a tap I can feel when I do something, so that I know it worked without looking closely.

- Tapping a card in the list plays a heavy haptic tap.
- Deleting a card plays a medium haptic tap.
- A successful scan vibrates the phone (CARD-2).
- Choosing a colour plays a selection haptic (1.3).

**Since:** 1.0
**Where:** `Cards/UI/Screens/CardListView.swift:42`, `Cards/UI/Screens/CardListView.swift:95`, `Cards/Scanner/ScannerViewControllerDelegate.swift:114`, `Cards/UI/Components/CardColorPicker.swift:34`
