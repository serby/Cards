# Settings

The Settings tab: what the app is, the switches it keeps, the data actions, and What's New. Each switch and action is specified in the story that owns it; this file says where they sit.

### SET-1: Find the app's settings in one place

As a card holder, I want one screen for the app's settings and data, so that I know where to look.

- The Settings tab shows a grouped list titled "Settings", in this order (1.3):
  - "What's New" on its own at the top (SET-2).
  - Display, with the Brightness Boost switch and its caption (BAR-4).
  - Locations, with the Arrival Notifications switch, its caption, and the message when notifications are off for the app (ARR-5).
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
