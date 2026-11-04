# Translator brief: Card Barcodes

## The app

Card Barcodes (called Cards inside the app) keeps the barcodes of your loyalty and membership cards on your iPhone, so you can leave the plastic cards at home. You add a card by scanning its barcode with the camera, or by typing its code in. At the till you open the card and the app shows its barcode large, with the screen turned up to full brightness, so the shop's scanner can read it straight off the screen. You can save the places where you use a card, such as a supermarket or a gym, found by postcode or address or by dropping a pin on a map. When you arrive at one, the app sends a notification that puts that card's barcode on your Lock Screen, ready before you have unlocked the phone. Cards sync between your devices through iCloud; there is no sign-in and no advertising.

## Audience

Everyday shoppers of every age, not technical people. They use the app for a few seconds at a time, often standing at a till with a queue behind them, so every word has to be understood at a glance.

## Tone

Plain, friendly and concise. Short everyday words, no jargon, no exclamation marks and no marketing. The copy speaks to the user directly ("your Lock Screen", "You're at …"); do the same, in the form of address Apple's own iOS interface uses in your language. Buttons and titles are short verbs or nouns ("Add Card", "Delete All Cards"); messages and hints are one short sentence. The English uses title case for buttons and titles; follow your language's own convention, as Apple does, rather than copying it.

## Where the strings appear

- **Cards list**: the main screen, titled "Cards". When it is empty it says "No Cards Yet" and asks you to scan the barcode on a loyalty card. Each row can show how far away the card's nearest saved place is, or "Here" when you are at one. A card's menu offers Move Up, Move Down and Delete.
- **Card screen**: the barcode, the card's name and code, and when it was created, with the nearest place ("At Westway", or "350 m · Westway"). A "Brightness Boost" button turns the screen to full brightness. "Edit" opens the form.
- **Add Card and Edit Card form**: for a new card, the camera at the top, or a message saying camera access is off; then Name, Code, Barcode Type, Colour, and Locations (the places where the barcode appears on the Lock Screen), then Save.
- **Add Location**: a map with a pin in the middle. Find a place by postcode or address, give it a name, set the radius, then Add. A place added without a name is saved as "Pinned location".
- **Settings**: the version and the developer, in a first section with no heading; Display (the Brightness Boost setting); and Data (Export as JSON, Import JSON, and Delete All Cards, which asks for confirmation). Import JSON opens a sheet for pasting an export, and an "Import Result" alert says how many cards were imported, that there were none, or that the JSON was not an export.
- **Arrival notification**: the title is the card's name; the body, "You're at %@. Your barcode is ready.", tells you that you are at a place and that your barcode is ready.
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
| arrival notification | the notification sent when you arrive at a saved place, which shows the card's barcode on the Lock Screen | The interface never names it; it describes what happens. Use Apple's word for notifications. |
| Brightness Boost | a setting and a button that turn the screen to full brightness while a barcode is showing | A feature name. Give it one short name and use it for the setting, the button, its VoiceOver labels and the announcements "Brightness Boost on" and "Brightness Boost off". The copy describes it as full brightness, and most languages name it that way too ("full brightness", "maximum brightness") rather than borrowing "boost". |
| Lock Screen | Apple's Lock Screen | Apple's own name for it in your language. |
| Home Screen widget, widget | the app's widget on the Home Screen | Apple's own words for the Home Screen and for a widget on it in your language. |
| postcode | a postal code, typed in to find a place; the same field takes an address | Your language's everyday word for postal code. |
| radius | how close to a place counts as arriving | |
| colour | the colour of a card's row in the list | Colour names (Red, Teal, Graphite and so on) follow Apple's names for the system colours. |
| export, import | saving all cards to a JSON file, and adding cards from one | Apple's words for exporting and importing. |

## Do not translate

- The app's name, **Card Barcodes**.
- Apple product and service names that Apple leaves in Latin script in your language: iPhone, iPad, iOS, iCloud, VoiceOver.
- **JSON**, the file format.
- Barcode format names: EAN-8, EAN-13, UPC-E, Code 39, Code 93, Code 128, PDF 417, Aztec. The one exception is **QR Code**, which takes your language's usual name for a QR code (which may be "QR Code" itself).
- The developer's name, **Paul Serby**, and anything that looks like a web address or a `cards://` link.
- The user's own content, which arrives through placeholders: card names, codes, place names and postcodes.
- **Westway**, the example place name in "Name, e.g. Westway": translate "Name, e.g." and keep Westway.
- Units. Distances such as "350 m" or "0.4 mi" are formatted by iOS for the user's region and arrive through a placeholder; never write a unit into a translation.

## What fills the placeholders

Placeholders are replaced at run time, so translate the words around them and keep them exactly as written.

- **A place name**: "At %@", "You're at %@", "You're at %@. Your barcode is ready.", "Added %@", "Deleted place %@" and "Map moved to %@".
- **A distance and a place**: "%@ · %@", as in "350 m · Westway", and the VoiceOver label "%@ from %@", where the distance is spoken in full, as in "350 metres from Westway". The distance comes first, then the place.
- **A radius**: "%@ radius", and "%@, %@ radius" with the place's name first.
- **The card's name**: "Deleted card %@".
- **The card's code**: "Card code: %@" and "Scanned code %@".
- **A barcode format and a code**: "Scanned %@: %@". The format's name arrives already translated and may contain your word for code, as QR Code and Code 128 do in English, so never add that word before or after it.
- **A date**: "Created on %@".
- **The postcode or address the user typed**: "No place found for “%@”". Use your language's quotation marks.
- **A version and a build number**: "%@ (%@)".
- **The developer's name**: "Created by %@".
- **A number of cards or places**: %lld, as in "This will permanently delete all %lld cards.", "Imported %lld cards", "Deleted %lld cards" and "Deleted %lld places". Where the source has plural forms, each form must suit every number in its category; in a language whose only form also covers 1, leave out any word for "all" beside the number.
