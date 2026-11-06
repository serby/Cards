# Card Barcodes product specification

This is what Card Barcodes does today, written as user stories. It is the reference for the app's behaviour: what a person can do, what they see, and the limits and edge cases that come with it. It was written from the code, the tests and the commit history, so where the code and this spec disagree, one of them has a bug.

The spec describes behaviour. How the code is built and the rules it follows are in [docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md), and how it looks is in [docs/STYLE.md](../docs/STYLE.md).

## How it is organised

One file per area of the app, listed in the [index](#index) below. Each file holds the stories for that area, and each story has an ID made of the file's prefix and a number, such as `CARD-3` or `ARR-2`. Stories refer to each other by ID where an area touches another.

IDs are permanent. When a story stops applying, delete it and leave its number unused, so an ID in a commit message or a test always means one thing.

## How a story is written

```markdown
### CARD-3: Add a card by typing its number

As a card holder, I want to type a card's number in, so that I can keep a card the camera can't read.

- Concrete, testable statements of what the app does.
- Limits, defaults, edge cases, error states, and wording where it matters.

**Since:** 1.0
**Where:** `Cards/Features/CardEditScreen.swift`, `CardsUITests/CardsUITests.swift`
**Notes:** Anything surprising, or a known gap.
```

- **Title:** short, in the person's terms.
- **Story:** `As a <person>, I want <goal>, so that <reason>.` The person is a card holder in most stories, sometimes someone using VoiceOver or a person with several devices.
- **Acceptance criteria:** a bullet list of statements that can be checked against the app: numbers, defaults, wording and what happens when something goes wrong. A criterion added after the story's first version can say so, as in "(1.3)".
- **Since:** the version that introduced the story: 1.0, 1.1, 1.3 or 1.4, or Unknown when the history doesn't say. "In preparation for 1.4" marks work planned or being built for the next version and not yet released; a criterion in an older story can be marked the same way.
- **Where:** the main source files and the tests that cover the story, as repo-relative paths, with `path:line` only when a line really helps.
- **Notes:** optional. Surprising behaviour and known gaps, stated as facts. No wishlists.

Versions: 1.0 was the first App Store version, prepared in December 2025. 1.1 is the tag `v1.1.0` (18 June 2026). The tag `v1.2` was never released and the version was renumbered 1.3, which is in preparation; everything after `v1.1.0` is in 1.3.

## Keeping it true

A change that adds or alters behaviour updates the matching stories in the same commit, and a new feature adds new stories. A change that removes behaviour deletes or edits its stories in the same commit. Fixes that bring the app back in line with a story need no spec change; a fix that changes what a story promises does.

Only write what the code does. If a criterion is wrong, fix the criterion or the code, whichever is wrong, and say which in the commit.

## Index

| File | Prefix | What it covers |
|------|--------|----------------|
| [cards.md](cards.md) | CARD | The list and grid, search and order, adding by scanning, typing or from a photo or a file, opening, editing, deleting, reordering, naming and symbols, and keeping each card's code its own |
| [barcodes.md](barcodes.md) | BAR | Supported barcode types, how codes are drawn, codes that can't be drawn, and the brightness boost |
| [colours-and-design.md](colours-and-design.md) | COL | The palette, custom colours, the card face, full-colour list rows, gradients, readable text, appearance and the app icon |
| [places.md](places.md) | PLACE | Adding places on the map or by postcode, the radius, Add current location, removing places, distances, a card's nearest places and location permission |
| [arrival-notifications.md](arrival-notifications.md) | ARR | A reminder on arrival, opening the card from it, the 20-region limit and watching the nearest places as you move, permission, the Settings switch and each card's own switch |
| [widget.md](widget.md) | WID | The Home Screen widget: nearest or chosen card, refresh, opening the card, layouts, tinted Home Screens and the snapshot |
| [sync-and-data.md](sync-and-data.md) | DATA | iCloud sync, export and import as JSON without duplicates, old exports, deleting every card, and where the store lives |
| [settings.md](settings.md) | SET | The Settings screen and What's New |
| [navigation.md](navigation.md) | NAV | The tabs, bringing the Cards tab forward, and `cards://` links |
| [accessibility.md](accessibility.md) | A11Y | VoiceOver, larger text sizes, announcements, touch targets and haptics |
| [platforms-and-privacy.md](platforms-and-privacy.md) | PLAT | iPhone, iPad, iPhone Duo, iOS 18 and later, language, and privacy: no accounts, analytics or tracking, location and camera on the device |
| [sharing.md](sharing.md) | SHARE | Sending a card as a link someone can add to their app, or as an image, and adding a shared card |
| [development.md](development.md) | DEV | The debug builds' Development tab: the Storybook and a test arrival notification |
