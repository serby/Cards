# Settings

The Settings tab: what the app is, the switches it keeps, the data actions, and What's New. Each switch and action is specified in the story that owns it; this file says where they sit.

### SET-1: Find the app's settings in one place

As a card holder, I want one screen for the app's settings and data, so that I know where to look.

- The Settings tab shows a grouped list titled "Settings", in this order (1.3):
  - "What's New" on its own at the top (SET-2).
  - Display, with the Brightness Boost switch and its caption (BAR-4).
  - Locations, with the Arrival Notifications switch, its caption, and the message when notifications are off for the app (ARR-5), then the Show Card Where I Am switch and its caption (SET-3) (in preparation for 1.4).
  - Data, with "Export as JSON" (DATA-2), "Import JSON" (DATA-3) and "Delete All Cards" (DATA-5).
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
- Where a change has an American English text and the device's region is the US, that text is shown.
- A change of a kind the app doesn't know is left out, and the rest of the changelog still shows.
- `changelog.json` is also the source of `CHANGELOG.md` and the App Store's What's New text (`scripts/generate-changelog.ts`), so the app and the store say the same thing.

**Since:** 1.3
**Where:** `Cards/UI/Screens/ChangelogView.swift`, `Cards/Core/Services/ChangelogStore.swift`, `Cards/Core/Models/Changelog.swift`, `Cards/UI/Screens/SettingsListView.swift`, `changelog.json`, `scripts/lib/changelog.ts`, `scripts/generate-changelog.ts`, `scripts/check-changelog.ts`, `CardsTests/ChangelogTests.swift`

### SET-3: See the card for where I am at the top of the list

As a card holder, I want the card for the place I am in shown in full above my other cards, so that I can scan it straight away.

- Settings > Locations has a "Show Card Where I Am" switch, below Arrival Notifications, with the caption "Shows the card for where you are at the top of your cards." It is off until you turn it on, and it is kept on the device and doesn't sync (the `showsCardWhereYouAre` user default).
- With the switch on, when you are inside one of a card's places (PLACE-6), the Cards tab shows that card in full above the grid: its face, name, barcode and number, as on the card screen (CARD-4). If you are inside places for several cards, it shows the card whose place is nearest.
- Tapping the full card opens it.
- When you leave the place, or turn the switch off, the full card goes and the grid moves up.
- The card still appears in the grid as well.

**Since:** In preparation for 1.4
**Where:** `Cards/UI/Screens/SettingsListView.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/UI/Screens/CardListView.swift`, `Cards/Features/CardListScreen.swift`, `CardsUITests/CardsUITests.swift` (`testShowCardWhereIAmSwitch`)
