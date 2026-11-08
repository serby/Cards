# Translator brief: Card Barcodes

## The app

Card Barcodes (called Cards inside the app) keeps the barcodes of your loyalty and membership cards on your iPhone, so you can leave the plastic cards at home. You add a card by scanning its barcode with the camera, by choosing a photo, a screenshot or a PDF of it, or by typing its code in, and you can give it a colour and an icon. At the till you open the card and the app shows its barcode large, with the screen turned up to full brightness, so the shop's scanner can read it straight off the screen. You can save the places where you use a card, such as a supermarket or a gym, found by searching for a shop, a street, a town or a postcode, or by dropping a pin on a map. When you arrive at one, a notification reminds you of the card, and tapping it opens the card. You can search and sort your cards, and share a card as a link someone else can add to their own Card Barcodes, or as a picture. Cards sync between your devices through iCloud; there is no sign-in and no advertising.

## Audience

Everyday shoppers of every age, not technical people. They use the app for a few seconds at a time, often standing at a till with a queue behind them, so every word has to be understood at a glance.

## Tone

Plain, friendly and concise. Short everyday words, no jargon, no exclamation marks and no marketing. The copy speaks to the user directly ("your Lock Screen", "You're at …"); do the same, in the form of address Apple's own iOS interface uses in your language. Buttons and titles are short verbs or nouns ("Add Card", "Delete All Cards"); messages and hints are one short sentence. The English uses title case for buttons and titles; follow your language's own convention, as Apple does, rather than copying it.

## Where the strings appear

- **Cards list**: the main screen, titled "Cards", a grid of card tiles. When it is empty it says "No Cards Yet" and asks you to scan the barcode on a loyalty card. A tile can show how far away the card's nearest saved place is, or "Here" when you are at one. A tile's menu offers Move Up, Move Down and Delete. The toolbar has a search field ("No Cards Match" when nothing matches) and a Sort menu ("Sort By": Last Viewed, Custom Order, Location). With Show Card Where I Am on, the card for the place you are at is shown in full above the others.
- **Card screen**: the card's face, with its name, icon and colour, the barcode, the card's code and when it was created, with the nearest place ("At Boulder Barn", or "350 m · Boulder Barn"). A card with several places lists the nearest ("Nearest places", "%lld more places"), each opening in Maps. A "Brightness Boost" button turns the screen to full brightness, a Share menu sends the card as a link or a picture ("Share Link", "Share Image"), the code can be copied ("Copy card code", "Copied"), "Add current location" saves where you are as one of its places, and "Edit" opens the form.
- **Add Card and Edit Card form**: for a new card, the camera at the top, with a torch button and tap to focus, or a message saying camera access is off or there is no camera; under it, Choose Photo and Choose File read a barcode from a picture or a PDF ("Reading the barcode…", "Choose a Barcode" when there are several). Then Name, Code ("Another card already uses this code."), Barcode Type, Icon (a grid of icons in groups, such as Food and drink), Colour (23 colours and a custom colour), Locations (the places where the card reminds you), Notify When I Arrive, and, when editing, Delete Card, which asks first. Save.
- **Add Location and Edit Location**: a map with a pin in the middle. Search for a place (a shop, an address, a street, a town or a postcode) and pick one of the suggestions, or drag the map; the place is named from the map, and the name can be changed ("Name, e.g. Boulder Barn"). Set the radius, then Add (or Save when changing a place). A place added without a name is saved as "Pinned location".
- **Settings**: What's New (every version's changes) in a first section; Display (the Brightness Boost setting); Locations (Arrival Notifications, which turns every card's reminder on or off, and Show Card Where I Am); iCloud (the iCloud Sync switch, which keeps the cards in the user's own iCloud account so they are on all their devices, and, when it is off, "Delete Cards from iCloud", which asks first and then says how it went); Data (Export as JSON, Import JSON, and Delete All Cards, which asks for confirmation); Privacy (Share Diagnostics, a switch that lets the app send its developer crash reports and performance data, with a note on iOS's own Share With App Developers setting, which the app can't change); Acknowledgements (the open source software the app is built with, each row opening its licence, which stays in English); and the version and the developer. Import JSON opens a sheet for pasting an export or choosing a file ("Choose File"), and an "Import Result" alert says how many cards were imported and how many were left out, and why (already in Card Barcodes, in the file more than once, or missing a name or code), or that the JSON was not an export.
- **Arrival notification**: the title is the card's name; the body, "You're at %@. Your barcode is ready.", tells you that you are at a place and that your card is ready to open.
- **Shared cards**: a link to a card opens an "Add Card?" sheet showing the card, which adds it, or says "You already have this card." or "This link doesn't contain a card."
- **Home Screen widget** (its own catalogues, under CardsWidget): a medium widget that shows one card's name, how far away it is and its barcode, so the user can scan it from the Home Screen. In the widget gallery it is called "Card", with a one-sentence description. By default it shows the card whose place is nearest ("Nearest card"); its settings, titled "Choose Card", let the user pick a card instead. A small refresh button ("Find nearest card", the action "Find Nearest Card") looks for the nearest card again. With no cards it says "No cards yet" and asks the user to add one in the app; a code that cannot be drawn says so in place of the barcode. The widget is small: keep its text as short as the English. It asks for location access with its own reason, in its InfoPlist catalogue. The distances, place names, colours and barcode formats it shares with the app come from the same views and must read exactly as they do in the app; the tool copies them across.
- **VoiceOver**: many strings are spoken labels, hints and announcements, such as "Card code: %@", "Opens the card for editing" and "Brightness Boost on". Translate them the way Apple writes VoiceOver labels and hints in your language: a label names the thing, a hint says what happens when it is used ("Saves the card", "Sets the code for this card's barcode"), never what to do, and an announcement says what just happened ("Deleted card %@").
- **Permission prompts** (InfoPlist catalogues): the reasons iOS shows when the app asks to use the camera and your location ("The camera is used to …", "Your location is used to …"), and when the widget asks for your location ("Your location lets the widget …"), plus the app's name. Follow Apple's style for these system prompts: full sentences that end with a full stop.

## Glossary

Use one translation for each term everywhere, including in VoiceOver labels and hints.

| English | What it means here | Guidance |
|---|---|---|
| card | a loyalty or membership card the user has saved in the app | The everyday word for a shop loyalty or membership card. "Cards" as the list title is the plural of the same word. Not a bank card or a playing card. |
| barcode | the image the shop's scanner reads, in any format, QR codes included | The common word for barcode. Use it for every format, as the English does. |
| code | the number or text the barcode encodes, shown under it and typed in by hand | The card's number, not a password, PIN or discount code. A code can be letters as well as digits, so avoid a word that means only "number". |
| barcode type | the barcode format (EAN-13, QR Code and so on) | "Format" or "type" of barcode, whichever Apple-style UI in your language prefers. |
| scan | the user scans a card's barcode with the camera to add it; separately, the shop's scanner scans the barcode on the screen | Use the verb Apple uses for scanning a code with the camera. Where that verb also means erase or clear, add the word that makes it optical. |
| location, place | a saved place where the user uses the card: a name, a point found by postcode or address or by the pin, and a radius | "Location" in titles and buttons, "place" in sentences. Where your language has one word for both, use it for both. Not the phone's own location setting, which Apple calls Location Services. |
| map pin, Pinned location | the pin in the middle of the Add Location map, and the name a place gets when it is added there without one | Apple Maps' word for a pin. For "Pinned location", the name Apple Maps gives a place marked on the map (its "Marked Location"), not a word for pinning something to the top of a list. |
| arrival notification | the notification sent when you arrive at a saved place, which reminds you of the card and opens it when tapped | The interface never names it; it describes what happens. Use Apple's word for notifications. |
| Brightness Boost | a setting and a button that turn the screen to full brightness while a barcode is showing | A feature name. Give it one short name and use it for the setting, the button, its VoiceOver labels and the announcements "Brightness Boost on" and "Brightness Boost off". The copy describes it as full brightness, and most languages name it that way too ("full brightness", "maximum brightness") rather than borrowing "boost". |
| Lock Screen | Apple's Lock Screen | Apple's own name for it in your language. |
| Home Screen widget, widget | the app's widget on the Home Screen | Apple's own words for the Home Screen and for a widget on it in your language. |
| postcode | a postal code, typed in to find a place; the same field takes an address | Your language's everyday word for postal code. |
| radius | how close to a place counts as arriving | |
| colour | the colour of a card's tile, face and widget | Colour names (Red, Teal, Graphite and so on) follow Apple's names for the system colours. |
| export, import | saving all cards to a JSON file, and adding cards from one | Apple's words for exporting and importing. |
| icon | the small picture a card can carry on its tile and face, chosen from a grid | Apple's word for an icon in your language. In English it is always "icon", never "symbol". |
| share | sending a card to someone as a link or a picture | Apple's word for the Share button and share sheet. |
| search, sort | finding cards by name, and putting them in an order | Apple's words, as in Search fields and Sort menus. |
| torch | the camera's light, for scanning in the dark | Apple's word for the flashlight in Control Centre in your language. |
| Notify When I Arrive, Show Card Where I Am, Arrival Notifications | the card's own reminder switch, the Settings switch that puts the card for where you are above the others, and the Settings switch for every reminder | Switch titles. Keep them short, and use the same words where other strings name them. |
| What's New | the screen listing each version's changes | Apple's own title for What's New in your language. |

## Do not translate

- The app's name, **Card Barcodes**.
- Apple product and service names that Apple leaves in Latin script in your language: iPhone, iPad, iOS, iCloud, VoiceOver.
- **JSON**, the file format.
- Barcode format names: EAN-8, EAN-13, UPC-E, Code 39, Code 93, Code 128, PDF 417, Aztec. The one exception is **QR Code**, which takes your language's usual name for a QR code (which may be "QR Code" itself).
- The developer's name, **Paul Serby**, and anything that looks like a web address or a `cards://` link.
- The user's own content, which arrives through placeholders: card names, codes, place names and postcodes.
- **Boulder Barn**, the made-up example place name in "Name, e.g. Boulder Barn": translate "Name, e.g." and keep Boulder Barn. Examples are always made-up businesses, never real ones.
- Icon names are translated; the names of barcode kinds the app cannot show (Data Matrix, ITF-14, Codabar) are not.
- Units. Distances such as "350 m" or "0.4 mi" are formatted by iOS for the user's region and arrive through a placeholder; never write a unit into a translation.

## What fills the placeholders

Placeholders are replaced at run time, so translate the words around them and keep them exactly as written.

- **A place name**: "At %@", "You're at %@", "You're at %@. Your barcode is ready.", "Added %@", "Deleted place %@" and "Map moved to %@".
- **A distance and a place**: "%@ · %@", as in "350 m · Boulder Barn", and the VoiceOver label "%@ from %@", where the distance is spoken in full, as in "350 metres from Boulder Barn". The distance comes first, then the place.
- **A radius**: "%@ radius", and "%@, %@ radius" with the place's name first.
- **The card's name**: "Deleted card %@".
- **The card's code**: "Card code: %@" and "Scanned code %@".
- **A barcode format and a code**: "Scanned %@: %@". The format's name arrives already translated and may contain your word for code, as QR Code and Code 128 do in English, so never add that word before or after it.
- **A date**: "Created on %@".
- **The postcode or address the user typed**: "No place found for “%@”". Use your language's quotation marks.
- **A version and a build number**: "%@ (%@)".
- **The developer's name**: "Created by %@".
- **A number of cards or places**: %lld, as in "This will permanently delete all %lld cards.", "Imported %lld cards", "Deleted %lld cards" and "Deleted %lld places". Where the source has plural forms, each form must suit every number in its category; in a language whose only form also covers 1, leave out any word for "all" beside the number.
- **Two sentences of the import result**: "%@ %@" joins them, the first then the second. Keep the order; use your language's space, or none, between sentences.
- **A street and an area**: "%@, %@", the name a place gets from the map, as in "Portobello Road, Notting Hill".
- **A change in What's New**: "New: %@", "Improved: %@" and "Fixed: %@", read by VoiceOver before the change's text.

## Languages

The app ships in British English (the source, `en`) and the languages in the project's `knownRegions`: Spanish (`es`, Spain), German (`de`) and Japanese (`ja`). The App Store listing has en-GB, en-US, es-ES, es-MX, de-DE and ja versions in `metadata/`, with screenshot captions in `screenshots/store/<locale>/captions.json`; the changelog carries the same languages (`changelog.json`, the release skill).

French (`fr`), Italian (`it`), Arabic (`ar`), Traditional Chinese (`zh-Hant`), Brazilian Portuguese (`pt-BR`), Korean (`ko`) and Simplified Chinese (`zh-Hans`) were translated and reviewed, then held back so the app ships in waves: French and Italian next, then Arabic, Traditional Chinese and Brazilian Portuguese; Korean and Simplified Chinese are on hold. Their style guides stay in `l10n/languages/`. Their last translations are in commit 279189d, before 1.4's new strings were translated. To bring one back:

1. `node scripts/add-language.ts <code> --from 279189d` adds it to `knownRegions`, restores every translation whose English has not changed since, and translates the rest with the style guide.
2. Review the new translations as for any change of copy (docs/DEVELOPMENT.md, "Add or change copy"), and capture its screens (`make capture-l10n LANGS=<code>`).
3. Add its store listing (`metadata/<locale>/`), captions (`screenshots/store/<locale>/captions.json`), changelog texts and the website's words (`Website/site.json`), then refresh the screenshots at release.
4. For Arabic, the first right-to-left language, run the UI tests in it too: `CardsRightToLeftUITests`, `CardPlacesAndSettingsRightToLeftUITests`, `CardsRightToLeftLargeTextAuditTests` and `CardFormRightToLeftLargeTextAuditTests` force right to left in English until then.
