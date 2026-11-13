# Platforms and privacy

The devices and systems Card Barcodes runs on, the language it speaks, what it does and doesn't do with your data, when it asks for a rating, and where people read about it: the App Store listing and the website.

### PLAT-1: Use the app on my iPhone

As a card holder, I want the app on my iPhone, so that my cards are in my pocket.

- The app runs on iOS 18.0 and later.
- On iPhone it is portrait only.
- It is called "Card Barcodes" on the Home Screen.
- Features of iOS 26 and later are used only where available, such as MapKit's naming of a place (PLACE-10).

**Since:** 1.0
**Where:** `Info.plist`, `Cards.xcodeproj/project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET = 18.0`)

### PLAT-2: Use the app on my iPad

As a person with several devices, I want the app on my iPad too, so that my cards are there when I have it with me.

- The app runs on iPad, in every orientation.
- It has one window. It can't open a second window of itself.
- With iCloud, the iPad has the same cards as the iPhone (DATA-1).

**Since:** 1.1
**Where:** `Info.plist` (`UISupportedInterfaceOrientations~ipad`, `UIApplicationSupportsMultipleScenes`), `Cards.xcodeproj/project.pbxproj` (`TARGETED_DEVICE_FAMILY = "1,2"`)
**Notes:** 1.0 was iPhone only.

### PLAT-3: Use the app on iPhone Duo

As a card holder with an iPhone Duo, I want the app to work on it, so that my cards are on the phone I carry.

- The app runs on iPhone Duo as an iPhone app.
- Scrolling the edit form puts the keyboard away, so the colour and location sections can be reached on the smaller outer display (CARD-5).
- The App Store screenshots are captured on the iPhone Duo's outer display, among other devices, and its App Store images show them on a drawing of the device (PLAT-13).

**Since:** 1.3
**Where:** `Cards/UI/Screens/CardEditView.swift`, `CardsUITests/CardsScreenshotTests.swift`, `CardsUITests/CardsWidgetScreenshotTests.swift`
**Notes:** Nothing in the app's code targets iPhone Duo. 1.3 is the first version captured and described for it.

### PLAT-4: Use the app without an account, ads or tracking

As a card holder, I want an app that doesn't watch me, so that I can trust it with my cards.

- There is no account or sign-in. Sync uses your own iCloud account (DATA-1), and can be turned off (DATA-8).
- In preparation for 1.5, the iPhone sends the Apple Watch paired with it a copy of every card, without its notes, by Apple's WatchConnectivity, straight from one of your devices to the other and with iCloud Sync on or off (WATCH-1). The watch keeps it in its own app's container. Nothing goes anywhere else.
- There are no ads, analytics or tracking, and the app makes no network requests of its own. It sends no diagnostics yet (PLAT-11).
- The only third-party code is RSBarcodes_Swift, which draws barcodes on the device, and Settings > Acknowledgements shows its licence (PLAT-12).
- The app times its own cold and warm starts and writes them to the device's log, and nowhere else.
- The app declares that it uses no non-exempt encryption.

**Since:** 1.0
**Where:** `Cards/Core/Services/PerformanceTracker.swift`, `Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `Info.plist`, `Cards/Core/Services/WatchSync.swift`, `Website/templates/privacy.html`

### PLAT-5: Keep my location on my device

As a card holder, I want my location to stay on my phone, so that nobody learns where I go.

- Your current location is only used on the device: for distances (PLACE-6), the widget's nearest card (WID-1), where the map opens (PLACE-1) and which places are watched for arrivals (ARR-3). The widget keeps its last reading in the App Group on the device, and it never goes into iCloud Sync, an export or a share (WID-1).
- In preparation for 1.5, the Apple Watch app finds where the watch is with its own location, only while it is open and only with your permission, for its distances and to open the card for the place you are at (WATCH-4). Its readings stay on the watch: it keeps none and sends none to the iPhone or anywhere else.
- The places you add are stored with the card, and sync and export with it (DATA-1, DATA-2).
- Arrival notifications are watched by iOS on the device, with no server involved (ARR-1).
- The map and the place search use Apple's map services, which receive the area shown or the text searched for (PLACE-2). Since 1.4 naming a place sends Apple Maps the point under the pin, or where you are when the sheet opens (PLACE-10).

**Since:** 1.3
**Where:** `Cards/Core/Services/LocationService.swift`, `CardsWidget/WidgetLocation.swift`, `Cards/Core/Services/PlaceSearch+MapKit.swift`, `Cards/Features/ArrivalScheduler.swift`, `Cards/Core/Services/NotificationClient.swift`, `CardsWatch/Services/WatchLocation.swift`, `Website/templates/privacy.html`

### PLAT-6: Know the camera is only used to scan

As a card holder, I want the camera used only when I am scanning a card, so that it is never on without me knowing.

- The camera only runs while the add form is showing (CARD-2), and stops when the form goes away or a code is read.
- The form asks for camera access before it starts the camera, and never starts it while access is off (CARD-2) (1.3).
- Frames are read on the device for barcodes and never recorded, stored or sent.

**Since:** 1.0
**Where:** `Cards/Scanner/ScannerViewControllerDelegate.swift`, `Cards/Scanner/CameraScannerView.swift:21-26`, `Cards/Scanner/CameraScannerView.swift:46-106`

### PLAT-7: Read the app in my language

As a card holder, I want the app in my own language, so that I understand every screen.

- The app speaks British English, and, in preparation for 1.4, Spanish (Spain), German, Japanese, French and Arabic. It follows the language chosen for it in iOS Settings, or the device's language, and falls back to British English for any other.
- Every word on screen and every word VoiceOver speaks is translated, including the app's name under its icon, the permission prompts, the arrival notification, the Home Screen widget and its gallery entry, What's New for 1.4 (SET-2), and, in preparation for 1.5, the Apple Watch app and its location prompt (WATCH-2). The user's own words, card names, codes and place names, are shown as typed.
- Dates, distances and radii follow the device's region: "1,5 km" in Germany, "400 yd" in the UK, "0.93 mi" in the US. Distances are spoken in full by VoiceOver ("350 metres", "350 Meter").
- Counts use each language's plural forms: "1 card", "2 cards"; Japanese has one form for every number, and Arabic six.
- In Arabic the app is laid out right to left, as iOS lays out its own apps: tabs, lists, forms and the card grid start on the right.
- Card codes, version numbers and JSON read left to right in every language, and barcodes are never mirrored.
- An English device always shows English, never a translation, because `Info.plist` keeps `CFBundleDevelopmentRegion`.

**Since:** 1.0 (English), in preparation for 1.4 (Spanish, German, Japanese, French and Arabic)
**Where:** `Cards/Localizable.xcstrings`, `Cards/InfoPlist.xcstrings`, `CardsWidget/Localizable.xcstrings`, `CardsWidget/InfoPlist.xcstrings`, `CardsWatch/Localizable.xcstrings`, `CardsWatch/InfoPlist.xcstrings`, `Cards.xcodeproj/project.pbxproj` (`knownRegions`), `CardsTests/LocalisationBundleTests.swift`, `CardsUITests/CardsLocalisationScreenshotTests.swift`
**Notes:** Italian, Traditional Chinese, Brazilian Portuguese, Korean and Simplified Chinese were translated on the localisation branch and are held back for later waves; `l10n/context.md` says how to bring each back. The right-to-left UI tests and audits run in Arabic (`CardsRightToLeftUITests`).

### PLAT-8: Be asked for a rating only once the app has helped

As a card holder, I want the app to ask what I think only after it has worked for me, and never while I am showing a card, so that a prompt never gets between me and the till.

- The app asks for a rating with Apple's own prompt (`requestReview`), which offers stars and an optional review. The app never shows a prompt of its own and never sends you to the App Store.
- It counts the calendar days on which a card's screen opened (CARD-4), in the device's calendar and time zone. Opening several cards, or one card many times, on one day counts as one day. A card opened at 23:50 and another at 00:10 count as two days. A time earlier than the last one counted, after the clock is set back, counts nothing.
- Once cards have been opened on three different days in the current version, it asks the next time you come back from a card to the list, a second after the list shows. Three days means the app has worked at a till on separate trips, not just on the day it was tried, so it can never ask on the day it was installed or first opened.
- It asks only with the list showing in the Cards tab and the app in front. Not while a card or its edit form shows, or while the "Add Card?" sheet (SHARE-3) is up or the search field (CARD-11) has text in it; a return that does not fit leaves it due for the next one. Leaving the edit form, by deleting a card from it or cancelling Add Card, is not a return from a card and does not ask.
- It asks at most once per version, as Apple advises. The first card opened in a new version starts the count again, so each version needs its own three days.
- Apple decides whether its prompt appears: at most three times in 365 days, never in TestFlight builds, and not at all once the person has turned off In-App Ratings & Reviews in the App Store settings. Debug builds show it on every request.
- The counts are kept on the device under `reviewPrompt` and don't sync, so each device counts its own days (DATA-1). They never leave the device (PLAT-4).
- It never asks in UI tests (`-uiTesting` or `CARDS_UI_TESTING=1`) or the screenshot runs (`-screenshotSeed`), which do not count days either. The Storybook and previews show the pure views, which never ask.

**Since:** 1.4
**Where:** `Cards/Core/Models/ReviewPrompt.swift`, `Cards/Core/Models/DeviceSettings.swift`, `Cards/Features/CardListScreen.swift`, `Cards/App/DevelopmentHooks.swift` (`asksForReviews`), `CardsTests/ReviewPromptTests.swift`
**Notes:** The card shown in full above the grid where you are (SET-3) is not counted, because it never opens a card's screen.

### PLAT-9: Find the app in the App Store in my language

As someone looking for a card wallet, I want the App Store listing in my language, so that I can tell what the app does before I download it.

- The listing has British English (en-GB), American English (en-US), Spanish for Spain (es-ES), Spanish for Mexico (es-MX), German (de-DE) and Japanese (ja) versions, in preparation for 1.4. Each one says the same thing in its own words, with the wording people search for there: "Fidelización" in Spain, "Cartera" in Mexico, "Kundenkarten" in Germany, "ポイントカード管理" in Japan.
- Every listing keeps the name "Card Barcodes" and localises the part after the colon, within 30 characters. Names, subtitles, screenshot captions and the creative assets' phrases never mention the price; the description and promotional text may say the app is free.
- Each listing has its own keywords, within 100 bytes, with no word already in its name or subtitle and no competitor's name.
- Each listing's What's New is that version's changelog in its language (SET-2), and its screenshots and creative assets (the product page header and search result on iOS 27) show the app in its language, with captions in it.
- App Review's notes are written once, in British English.

**Since:** 1.4
**Where:** `metadata/<locale>/`, `screenshots/store/<locale>/captions.json`, `screenshots/store/<locale>/creative-asset.json`, `scripts/check-metadata.ts`, `scripts/check-store-images.ts`, `scripts/upload-metadata.ts`, `scripts/upload-screenshots.ts`

### PLAT-10: Read about the app on its website

As someone deciding whether to get the app, I want a website that says what it does, in my language, so that I can find out before I open the App Store.

- https://cards.serby.net is built from the App Store listing, the changelog and the app, so it says what they say: the listing's name, subtitle and description, the promise that the app is free, with no ads, no in-app purchases and no limit on cards, and always will be, the store images with their captions read as their descriptions, and a link to the App Store. Since 1.4 the site shows the iPhone Duo's images, which are nearer square than the iPhone's, so a row of them fits the page (PLAT-13).
- It lists the languages the app speaks, each named in its own language and in English (PLAT-7), and which iOS it needs (PLAT-1).
- What's New shows the current version and, under Earlier versions, every one before it, with the app's own words for What's New, the version and each kind of change (SET-2). A change with no translation shows in British English, as in the app. A version still in preparation is not shown.
- It has a page in British English at `/` and one in each of the app's other languages, `/es/`, `/de/` and `/ja/`, made from the Spain, Germany and Japan listings, linked to each other for search engines and by a language switcher. American English and Mexican Spanish read the British English and Spanish pages, as they read the app.
- The privacy policy, in British English at `/privacy.html`, the listings' privacy URL, says what leaves the device (PLAT-4, PLAT-5) and names the third-party code from the app's package pins.
- The share link page (`/add`, SHARE-1), App Review's sample codes (`/demo.html`) and the universal link file are served as they are.
- The pages work without JavaScript, follow light and dark appearance and Increase Contrast, use the app's pink, and keep every text at WCAG AA contrast. Since 1.4 the store images sit in one row that scrolls sideways, as the App Store shows them.
- The site is deployed only once the British English page's store images are present. Until another language's images are composed its page leaves them out, so it never shows another language's or version's pictures.
- Since 1.4 the site counts visits with Google Analytics, through Google Tag Manager, only for visitors who allow it. A banner on every page made from `page.html` asks, in the page's language, "Can this website count your visit with Google Analytics? It uses cookies to do so. The app itself never tracks you.", with "No thanks" and "Allow". Until a visitor chooses Allow no Google script loads and no cookie is set. The choice is kept in the browser, "Cookie Settings" at the foot of every page asks again, and choosing No thanks removes Google Analytics' cookies. The share link page and App Review's sample codes never load it. The privacy policy says what is sent and that the app itself has no analytics (PLAT-4).

**Since:** 1.4
**Where:** `scripts/build-website.ts`, `scripts/lib/website.ts`, `Website/site.json`, `Website/templates/`, `Website/static/`, `.github/workflows/website.yml`, `scripts/website.test.ts`

### PLAT-11: Choose whether the app shares diagnostics

As a card holder, I want to decide whether the app sends its developer crash reports, so that nothing about my use of it leaves my device unless I agree.

- Settings > Privacy has a "Share Diagnostics" switch with the caption "Lets Card Barcodes send crash reports and performance data to its developer, to find and fix problems. Your cards and places are never included." It is on until you turn it off.
- Under it: "iOS shares its own crash reports with app developers only when Share With App Developers is on, in Privacy & Security > Analytics & Improvements in the Settings app. Card Barcodes can't change that setting." An app has no way to read or change that setting, so the app only says where it is.
- The switch is kept on the device under `sharesDiagnostics` and doesn't sync.
- The app sends no diagnostics yet. Crash reporting added later (Sentry is planned) must send nothing while the switch is off, must never send cards, codes, places or locations, and must be named in the privacy policy (PLAT-10), the App Store privacy details and Acknowledgements (PLAT-12) before it ships.

**Since:** 1.4
**Where:** `Cards/UI/Screens/SettingsListView+Privacy.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/Core/Models/DeviceSettings.swift`

### PLAT-12: See the open source software the app uses

As a card holder, I want to see the open source software the app is built with and its licences, so that I know what is in it and its authors are credited.

- Settings has an "Acknowledgements" row, in a section of its own above Version. It opens a screen titled "Acknowledgements" with a row for each library, with its name and its licence's name, as "RSBarcodes_Swift" and "MIT License", and the footer "Card Barcodes is built with this open source software. Each row opens its licence."
- A library's row opens a screen titled with its name showing its licence in full, as the project ships it, in English, which can be selected and copied, and a "Project Website" row that opens the project's page in the browser.
- Every package in `Package.resolved` is listed, and a unit test fails when one is missing (`PrivacySettingsTests`).

**Since:** 1.4
**Where:** `Cards/Core/Models/OpenSourceLibrary.swift`, `Cards/UI/Screens/SettingsListView+Privacy.swift`, `Cards/UI/Screens/AcknowledgementsView.swift`, `Cards/UI/Screens/OpenSourceLicenceView.swift`, `CardsTests/PrivacySettingsTests.swift`

### PLAT-13: See what the app does from its App Store images

As someone looking at the listing, I want its images to show what the app does for me, the way it looks on a phone, so that I can tell in a few seconds whether it is the app I want.

- Since 1.4 the images lead with what sets the app apart, in this order (docs/BRAND.md):
  1. "Your card, ready when you arrive": the Cards tab with the card for where you are in full at the top (SET-3).
  2. "On your Home Screen": a Home Screen with the widget showing the card for where you are, and the app's icon, and nothing else (WID-1).
  3. "Your cards stay yours", with "No account", "No tracking" and "iCloud or this device": Settings at iCloud Sync, Data and Share Diagnostics (PLAT-4, DATA-8, PLAT-11).
  4. "No ads, no limits": a grid full of cards, sixteen made-up ones (PLAT-4). Captions never mention the price (PLAT-9), so not "free".
  5. "Share a card": the share menu with Share Link and Share Image (SHARE-1, SHARE-2).
  6. "Ready at the till": a card's screen (BAR-4, PLACE-9).
  7. "A reminder when you arrive": adding a place on the map (PLACE-1, ARR-1).
  Colours and icons, which the 1.3 images led with, are no longer one of them.
- Each image is the screen as it is on the device, captured by the screenshot UI tests in the listing's language with the status bar at 9:41, full signal and battery, drawn on the device: its display's own shape and corners, a thin black bezel and a metal frame, with nothing cropped or covered and no black bars. On iPhone Duo that is the outer display, with the tight corners and the spine on the hinge side.
- Above the device is the caption, on a white panel with rounded corners, as a card face holds its name: the title in bold dark ink and the subtitle in the lighter ink, or a row of chips in the brand pink. The background is the gradient of one of the card colours, a different one for each image, from the app's palette.
- Captions are in the system font, wrapped to balanced lines, at most two for the title and two for the subtitle, and made smaller when a language needs it; the panel grows to hold them and the device shrinks to fit below.
- Each device's image is drawn from a vector template, `screenshots/templates/<device>.svg`, which any SVG editor opens: the composer (`scripts/compose-store-images.ts`) fills it in from each listing's `captions.json` and the raw captures, and renders it with headless Chrome at the size App Store Connect takes, with no alpha channel. The colours come from `card-colours.json`, which a unit test keeps the same as the app's palette.
- The images show only made-up businesses (LANGUAGE.md).

**Since:** 1.4
**Where:** `screenshots/templates/`, `screenshots/store/<locale>/captions.json`, `scripts/compose-store-images.ts`, `scripts/lib/store-images.ts`, `scripts/store-images.test.ts`, `scripts/capture-screenshots.ts`, `CardsUITests/CardsScreenshotTests.swift`, `CardsUITests/CardsWidgetScreenshotTests.swift`, `Cards/Development/ScreenshotSeed.swift` (`insertMany`), `CardsTests/StoreImageColoursTests.swift`, `scripts/lib/website.ts` (`screenshotSuffix`), `scripts/check-store-images.ts`, `scripts/upload-creative-assets.ts`
- Since 1.4 the creative assets are a product page header (3840 x 1646) and a search result asset (3840 x 2560) for each listing, each with one short phrase in its language on the brand pink: the header "Your card, ready when you arrive", beside the card for where you are with card tiles fanned round it, and the search result "Your loyalty cards, ready to scan", beside the iPhone Duo showing the Cards tab. The phrase and the app's screen stay inside Apple's art safe area for each, so nothing that matters is cropped or covered; the tiles round them may be.

**Notes:** The templates are `iPhone.svg`, `iPad.svg` and `Duo.svg` for the screenshots and `Header.svg` and `Search.svg` for the creative assets. The creative assets crop the iPhone Duo captures.
