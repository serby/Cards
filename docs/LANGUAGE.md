# Card Barcodes language guide

How Card Barcodes words things: the app's text, notifications, the App Store listing and its screenshots, the website, the changelog, and the examples in code, tests, the spec and these docs. How the app looks is in [STYLE.md](STYLE.md).

## Spelling

- British English in everything people read: "colour", "postcode", "till". Swift's spelling in identifiers: `color`.
- The en-US App Store listing and changelog use American English where it differs: colour/color, till/checkout, postcode/ZIP code. Everything else is British English.

## Voice

- Plain and active. Short sentences that say what the person can do or what changed.
- No hype and no exclamation marks.
- Write "it is" and "that is" in full, and use no em or en dashes.
- Never "land" for shipping.
- Title Case for screen titles, buttons and switches ("Add Card", "Show Card Where I Am"). Sentence case for captions, messages, notifications and descriptions.

## Examples use made-up businesses

Never use a real business, brand or product as an example. That covers:

- the App Store listing and its screenshots;
- the website;
- placeholder and sample text in the app and the widget;
- sample data, previews, stories and screenshot seed data;
- tests, the spec and the docs.

Real names are other people's trademarks, so they don't belong on the store page (App Store Review Guideline 5.2.1). They also date quickly, and they make the app look tied to one shop.

Use this cast instead, so examples agree wherever they appear:

| Business | Its places | Stands in for |
|---|---|---|
| Joe's Market | Joe's Market Notting Hill, Joe's Market Kensington, Joe's Market Holland Park, and where an example needs more than five places, Joe's Market Earl's Court, Joe's Market Bayswater, Joe's Market Shepherd's Bush and Joe's Market Ladbroke Grove | A supermarket loyalty card |
| Local Roast Coffee | Local Roast Portobello, Local Roast Notting Hill | A coffee shop |
| Green Leaf Pharmacy | Green Leaf Shepherd's Bush | A pharmacy |
| Boulder Barn Climbing | Boulder Barn | A gym or climbing wall, and the QR code example |
| Honeycomb Rewards | None | A points card with no places |
| Nordic Nest Home | Nordic Nest Wembley | A furniture shop |
| Ladbroke Library | None | A library card |
| Corner Grocer | None | A name that matches no card, in search tests |

- **A new example:** invent an independent-sounding business, such as a first name and a trade ("Joe's Market") or something local ("Little Fern Bakery"), and add it to the table.
- **Codes:** these are made up too. Don't use a real card number or a real issuer's prefix.
- **Allowed:** real area names (Notting Hill, Kensington, Wembley) and generic words (supermarket, coffee shop, gym, library).

## Elsewhere

- Changelog entries and App Store release notes: the release skill, [.claude/skills/release/SKILL.md](../.claude/skills/release/SKILL.md).
- How stories in the spec are written: [spec/README.md](../spec/README.md).
- App Store field limits: `node scripts/check-metadata.ts` ([DEVELOPMENT.md](DEVELOPMENT.md), "Update the App Store listing").
