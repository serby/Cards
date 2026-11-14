# Settings

The Settings tab: what the app is, the switches it keeps, the data actions, and What's New. Each switch and action is specified in the story that owns it; this file says where they sit.

### SET-1: Find the app's settings in one place

As a card holder, I want one screen for the app's settings and data, so that I know where to look.

- The Settings tab shows a grouped list titled "Settings", white rows on the system's grouped grey, with room below the last section so it ends clear of the tab bar, in this order (1.3):
  - "What's New" on its own at the top (SET-2).
  - Display, with the Brightness Boost switch and its caption (BAR-4).
  - Locations, with the Arrival Notifications switch, its caption, and the message when notifications are off for the app (ARR-5), then the Show Card Where I Am switch and its caption (SET-3), then the Distances menu and its caption (SET-4), then the Maps menu and its caption (SET-5) (in preparation for 1.4).
  - iCloud, with the iCloud Sync switch and its caption, and with sync off "Delete Cards from iCloud" and its caption (DATA-8, DATA-9) (in preparation for 1.4).
  - Data, with "Export as JSON" (DATA-2), "Import JSON" (DATA-3) and "Delete All Cards" (DATA-5).
  - Privacy, with the Share Diagnostics switch, its caption and a note on iOS's own crash reports (PLAT-11) (in preparation for 1.4).
  - In preparation for 1.5: Privacy also has a Share Usage Data switch under it, on until it is turned off (PLAT-15).
  - "Acknowledgements", a row on its own that opens the open source software the app is built with (PLAT-12) (in preparation for 1.4).
  - Last, "Version", with the version and build number, as "1.3 (<build>)", and "Created by Paul Serby", which opens https://github.com/serby and has an external link icon. The Version row only shows when both numbers are known.
- Brightness Boost and Arrival Notifications are on by default. Both are kept on the device and don't sync (DATA-1).
- Each card also has its own arrival switch, in its edit form rather than here, which syncs with the card (ARR-6) (1.3).

**Since:** 1.0
**Where:** `Cards/UI/Screens/SettingsListView.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/UI/ViewState/CardViewState.swift`
**Notes:** Before 1.3 the version and author came first, followed by Display, Locations and Data.

### SET-2: See what changed in each version

As a card holder, I want to read what each version of the app changed, so that I know what is new after an update.

- Settings opens with a "What's New" row in a section of its own. It only shows when the app's changelog has at least one version.
- The row opens a screen titled "What's New" listing every version in the app's bundled `changelog.json`, newest first. The screen keeps the file's order, and `node scripts/check-changelog.ts` fails unless the file is newest first.
- Each version is a section headed "Version 1.3", with its date from the changelog, such as "4 November 2026". A version still in preparation has no date and shows none.
- Each change is a row with its text and an icon for its kind: new, improved or fixed. VoiceOver reads the kind first, as "New: …".
- Each change shows in the app's language: its translation for the language and region where it has one ("es-MX"), then for the language ("es", "de", "ja"), and otherwise its British English. Where a change has an American English text and the device's region is the US, that text is shown. Since 1.4, every change from 1.4 on is translated; older versions show in English.
- A change of a kind the app doesn't know is left out, and the rest of the changelog still shows.
- `changelog.json` is also the source of `CHANGELOG.md` and each App Store listing's What's New text (`scripts/generate-changelog.ts`), so the app and the store say the same thing in every language. `node scripts/check-changelog.ts` fails while the newest version lacks a text for any listing.

**Since:** 1.3
**Where:** `Cards/UI/Screens/ChangelogView.swift`, `Cards/Core/Services/ChangelogStore.swift`, `Cards/Core/Models/Changelog.swift`, `Cards/UI/Screens/SettingsListView.swift`, `changelog.json`, `scripts/lib/changelog.ts`, `scripts/generate-changelog.ts`, `scripts/check-changelog.ts`, `CardsTests/ChangelogTests.swift`

### SET-3: See the card for where I am at the top of the list

As a card holder, I want the card for the place I am in shown above my other cards, so that I can open it straight away.

- Settings > Locations has a "Show Card Where I Am" switch, below Arrival Notifications, with the caption "Shows the card for where you are at the top of your cards." It is off until you turn it on.
- The switch is kept on the device under `showsCardWhereYouAre` and doesn't sync, so each device has its own (DATA-1).
- With the switch on, when you are inside one of a card's places (PLACE-6), the Cards tab shows that card above the grid. In 1.4 it showed the card in full: its face, name, barcode and number, as on the card screen (CARD-4), at most 560 points wide.
- In preparation for 1.5 it shows a tighter lock-up of the card instead: the card face's top panel and nothing more, its icon, its name, where you are, as "At Joe's Market Notting Hill", and its number, in the face's monospaced type, on the card's colour with the face's corners and inset. It is the card face itself in a compact style, so it keeps the face's look as the face changes, and it is no wider than the card screen's face, centred (CARD-4). If you are inside places for several cards, it shows the one whose place you are nearest the middle of, which is also the first card in Location order (CARD-11).
- Tapping the card opens it, in preparation for 1.5 by zooming up from it (CARD-4). VoiceOver reads it as one button, the name and where you are, as "Joe's Market, You're at Joe's Market Notting Hill", with the hint "Opens the card for where you are".
- It goes while you search (CARD-11), and comes back when the search is cleared.
- When you leave the place, or turn the switch off, the full card goes and the grid moves up.
- The card still appears in the grid as well.

**Since:** 1.4
**Where:** `Cards/UI/Screens/SettingsListView.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/UI/Screens/CardListView.swift`, `Cards/UI/Components/CardFaceView.swift` (`CardFaceStyle.lockUp`), `Cards/Features/CardListScreen.swift`, `CardsUITests/CardPlacesAndSettingsUITests.swift` (`testShowCardWhereIAmSwitch`), `Cards/Core/Models/CardArrangement.swift`, `Cards/Core/Models/DeviceSettings.swift`, `CardsTests/CardArrangementTests.swift`, `CardsUITests/CardsUITests.swift` (`testCardWhereYouAre`)

### SET-4: Choose the units distances are shown in

As a card holder, I want distances in the units I think in, so that I can tell at a glance how far away a place is.

- Settings > Locations has a "Distances" menu, below Show Card Where I Am and above Maps (SET-5), with the caption "Automatic follows the measurement system in Language & Region in the Settings app."
- At the accessibility text sizes the choice sits under "Distances" and wraps onto as many lines as it needs, so "Automatic (Miles)" is never cut off. VoiceOver reads the menu as "Distances" with the choice as its value.
- It has three choices:
  - "Automatic", the default, listed with what it means on this device: "Automatic (Kilometres)" when the measurement system in Settings > General > Language & Region is Metric, and "Automatic (Miles)" when it is UK or US. Distances are then written as iOS writes road distances for that system, as they were before there was a choice: kilometres and metres for Metric, miles and yards for UK, and miles and feet for US.
  - "Kilometres": kilometres and metres, whatever the measurement system.
  - "Miles": miles and yards, whatever the measurement system.
- The choice applies to every distance the app shows: the tiles on the Cards tab (CARD-10), the card for where you are (SET-3), the card screen's top panel and its nearest places (PLACE-6, PLACE-9), the widget (WID-1), and what VoiceOver reads for each (A11Y-1). It also sets the unit of a place's radius in the location picker, the edit form and the "Add Card?" sheet: metres with Kilometres, and yards with Miles. Automatic counts as Kilometres or Miles, as its name says (PLACE-3).
- Distances are rounded as road distances are. Metres go to the nearest 10, or the nearest 50 from 300 m, and turn into kilometres from 900 m. Yards go to the nearest 10, or the nearest 50 from 100 yd, and turn into miles from half a mile. Kilometres and miles have two significant figures below 10, as "0.75 mi" or "4.2 km", and whole numbers above. Numbers are written in the style of the device's region, such as "1,2 km" in Germany.
- Location order on the Cards tab (CARD-11) sorts by distance, whatever the choice.
- Changing the choice changes every distance on screen straight away, and asks the widget to redraw (WID-7).
- The choice is kept on the device under `distanceUnits` and doesn't sync, so each device has its own (DATA-1). The app copies it for the widget (WID-7).

**Since:** 1.4
**Where:** `Cards/UI/Screens/SettingsListView.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/App/CardsApp.swift`, `Cards/Core/Models/DistanceUnits.swift`, `Cards/Core/Models/DistanceFormat.swift`, `Cards/Core/Models/DeviceSettings.swift`, `Cards/UI/Environment/DistanceUnitsEnvironment.swift`, `CardsTests/DistanceFormatTests.swift`, `CardsUITests/CardPlacesAndSettingsUITests.swift` (`testDistancesFollowTheSetting`)
**Notes:** iOS always has a measurement system, so Automatic always means Kilometres or Miles. In the US, Automatic keeps feet below half a mile, as iOS writes road distances there, while Miles always uses yards; the radius is in yards either way.

### SET-5: Choose the app places open in

As a card holder, I want a card's places to open in the maps app I use, so that I get directions where I am used to getting them.

- Settings > Locations has a "Maps" menu, below Distances, with the caption "Where a card's places open when you tap one. Google Maps opens in your browser if its app isn't installed."
- It has two choices, "Apple Maps", the default, and "Google Maps". iOS doesn't tell apps which maps app someone uses, so the app can't start on it, and starts on Apple Maps.
- The choice decides where the card screen opens a place: the place in the top panel (PLACE-6) and each place in its list (PLACE-9).
  - Apple Maps opens a pin at the place, labelled with its name, as before there was a choice: `https://maps.apple.com/?ll=<latitude>,<longitude>&q=<name>`.
  - Google Maps opens a pin at the place's position, in Google's Maps URL form, which opens Google Maps' app when it is installed and its website in the browser when it isn't: `https://www.google.com/maps/search/?api=1&query=<latitude>,<longitude>`. Google's form takes no name with a position, so the pin is unlabelled.
- VoiceOver's hint for a place says where it opens: "Opens this place in Maps", or "Opens this place in Google Maps".
- At the accessibility text sizes the choice sits under "Maps" and wraps, as Distances does (SET-4). VoiceOver reads the menu as "Maps" with the choice as its value.
- The choice is kept on the device under `mapsApp` and doesn't sync, so each device has its own (DATA-1).

**Since:** 1.4
**Where:** `Cards/Core/Models/MapsApp.swift`, `Cards/Core/Models/CardLocation.swift` (`mapsURL(in:)`), `Cards/Core/Models/DeviceSettings.swift`, `Cards/UI/Screens/SettingsListView+Menus.swift`, `Cards/UI/ViewState/MapsApp+Title.swift`, `Cards/UI/Environment/MapsAppEnvironment.swift`, `Cards/UI/Components/Text+OpensPlace.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/App/CardsApp.swift`, `CardsTests/CardPlacesTests.swift`, `CardsUITests/CardPlacesAndSettingsUITests.swift` (`testChooseTheMapsApp`)
**Notes:** In the EU (iOS 18.4 and later) and Japan (iOS 26.2 and later) people can choose a default navigation app, which iOS hands directions to through `geo-navigation://`. A pin isn't directions, so Apple Maps' choice still opens Apple Maps there.
