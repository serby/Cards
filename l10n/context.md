# Translator brief: Card Barcodes

## The app

Card Barcodes (called Cards inside the app) keeps the barcodes of your loyalty and membership cards on your iPhone, so you can leave the plastic cards at home. You add a card by scanning its barcode with the camera, or by typing its code in. At the till you open the card and the app shows its barcode large, with the screen turned up to full brightness, so the shop's scanner can read it straight off the screen. You can save the places where you use a card, such as a supermarket or a gym, found by postcode or by dropping a pin on a map. When you arrive at one, the app sends a notification that puts that card's barcode on your Lock Screen, ready before you have unlocked the phone. Cards sync between your devices through iCloud; there is no sign-in and no advertising.

## Audience

Everyday shoppers of every age, not technical people. They use the app for a few seconds at a time, often standing at a till with a queue behind them, so every word has to be understood at a glance.

## Tone

Plain, friendly and concise. Short everyday words, no jargon, no exclamation marks and no marketing. The copy speaks to the user directly ("your Lock Screen", "You're at …"); do the same, in the form of address Apple's own iOS interface uses in your language. Buttons and titles are short verbs or nouns ("Add Card", "Delete All Cards"); messages and hints are one short sentence. The English uses title case for buttons and titles; follow your language's own convention, as Apple does, rather than copying it.

## Where the strings appear

- **Cards list**: the main screen, titled "Cards". When it is empty it says "No Cards Yet" and asks you to scan the barcode on a loyalty card. Each row can show how far away the card's nearest saved place is ("At …" a place, or a distance and a place).
- **Card screen**: the barcode, the card's name and code, and when it was created. A "Brightness Boost" button turns the screen to full brightness. "Edit" opens the form.
- **Add Card and Edit Card form**: Name, Code, Barcode Type, Colour, and Locations (the places where the barcode appears on the Lock Screen), then Save.
- **Add Location**: find a place by postcode, give it a name, set the radius, then Add.
- **Settings**: About (version, developer), Display (the Brightness Boost setting), and Data (export the cards as JSON, import JSON, Delete All Cards, which asks for confirmation).
- **Arrival notification**: the title is the card's name; the body tells you that you are at a place and that your barcode is ready.
- **VoiceOver**: many strings are spoken labels, hints and announcements, such as "Card code", "Tap to edit this card's details" and "Brightness boost on". Translate them the way Apple writes VoiceOver labels and hints in your language: a label names the thing, and a hint says what happens.
- **Permission prompts** (InfoPlist catalogue): the reasons iOS shows when the app asks to use the camera and your location, plus the app's name. Follow Apple's style for these system prompts.

## Glossary

Use one translation for each term everywhere, including in VoiceOver labels and hints.

| English | What it means here | Guidance |
|---|---|---|
| card | a loyalty or membership card the user has saved in the app | The everyday word for a shop loyalty or membership card. "Cards" as the list title is the plural of the same word. Not a bank card or a playing card. |
| barcode | the image the shop's scanner reads, in any format, QR codes included | The common word for barcode. Use it for every format, as the English does. |
| code | the number or text the barcode encodes, shown under it and typed in by hand | The card's number, not a password, PIN or discount code. |
| barcode type | the barcode format (EAN-13, QR Code and so on) | "Format" or "type" of barcode, whichever Apple-style UI in your language prefers. |
| scan | the user scans a card's barcode with the camera to add it; separately, the shop's scanner scans the barcode on the screen | Use the verb Apple uses for scanning a code with the camera. |
| location, place | a saved place where the user uses the card: a name, a point found by postcode or a pin, and a radius | "Location" in titles and buttons, "place" in sentences. Not the phone's own location setting, which Apple calls Location Services. |
| arrival notification | the notification sent when you arrive at a saved place, which shows the card's barcode on the Lock Screen | The interface never names it; it describes what happens. Use Apple's word for notifications. |
| Brightness Boost | a setting and a button that turn the screen to full brightness while a barcode is showing | A feature name. Give it one short name and use it for the setting, the button and its VoiceOver labels; "Brightness boost on" and "off" announce its state. |
| Lock Screen | Apple's Lock Screen | Apple's own name for it in your language. |
| postcode | a postal code, typed in to find a place | Your language's everyday word for postal code. |
| radius | how close to a place counts as arriving | |
| colour | the colour of a card's row in the list | Colour names (Red, Teal, Graphite and so on) follow Apple's names for the system colours. |
| export, import | saving all cards to a JSON file, and adding cards from one | Apple's words for exporting and importing. |

## Do not translate

- The app's name, **Card Barcodes**.
- Apple product and service names that Apple leaves in Latin script in your language: iPhone, iPad, iOS, iCloud, VoiceOver.
- **JSON**, the file format.
- Barcode format names: QR Code, EAN-8, EAN-13, UPC-E, Code 39, Code 93, Code 128, PDF 417, Aztec.
- The developer's name, **Paul Serby**, and anything that looks like a web address or a `cards://` link.
- The user's own content, which arrives through placeholders: card names, codes, place names and postcodes.
- Example place names in placeholder text, such as **Westway** in "Name, e.g. Westway": translate "Name, e.g." and keep the place name.
- Units. Distances such as "350 m" or "0.4 mi" are formatted by iOS for the user's region and arrive through a placeholder; never write a unit into a translation.

## What fills the placeholders

Placeholders are replaced at run time, so translate the words around them and keep them exactly as written.

- **A place name**: "At %@", "You're at %@", "You're at %@. Your barcode is ready."
- **A distance and a place**: "%@ · %@" and "%@ from %@" (distance first, then place).
- **A distance**: "%@ radius".
- **The card's name**: "Card name: %@", "Barcode for %@".
- **A date**: "Created on %@".
- **A barcode format and a code**: "This is a %@ barcode with code %@".
- **The postcode the user typed**: "No place found for “%@”". Use your language's quotation marks.
- **A version and a build number**: "%@ (%@)".
- **The developer's name**: "Created by %@".
- **A number of cards**: %lld, as in "This will permanently delete all %lld cards." Where the source has plural forms, each form must suit every number in its category.
