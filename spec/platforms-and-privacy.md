# Platforms and privacy

The devices and systems Card Barcodes runs on, the language it speaks, and what it does and doesn't do with your data.

### PLAT-1: Use the app on my iPhone

As a card holder, I want the app on my iPhone, so that my cards are in my pocket.

- The app runs on iOS 18.0 and later.
- On iPhone it is portrait only.
- It is called "Card Barcodes" on the Home Screen.
- Features of iOS 26 and later are used only where available, such as the minimising tab bar (NAV-1).

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
- The App Store screenshots are captured on the iPhone Duo's outer display, among other devices.

**Since:** 1.3
**Where:** `Cards/UI/Screens/CardEditView.swift`, `CardsUITests/CardsScreenshotTests.swift`, `CardsUITests/CardsWidgetScreenshotTests.swift`
**Notes:** Nothing in the app's code targets iPhone Duo. 1.3 is the first version captured and described for it.

### PLAT-4: Use the app without an account, ads or tracking

As a card holder, I want an app that doesn't watch me, so that I can trust it with my cards.

- There is no account or sign-in. Sync uses your own iCloud account (DATA-1).
- There are no ads, analytics or tracking, and the app makes no network requests of its own.
- The only third-party code is RSBarcodes_Swift, which draws barcodes on the device.
- The app times its own cold and warm starts and writes them to the device's log, and nowhere else.
- The app declares that it uses no non-exempt encryption.

**Since:** 1.0
**Where:** `Cards/Core/Services/PerformanceTracker.swift`, `Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `Info.plist`, `Website/src/privacy.html`

### PLAT-5: Keep my location on my device

As a card holder, I want my location to stay on my phone, so that nobody learns where I go.

- Your current location is only used on the device: for distances (PLACE-6), the widget's nearest card (WID-1), where the map opens (PLACE-1) and which places are watched for arrivals (ARR-3).
- The places you add are stored with the card, and sync and export with it (DATA-1, DATA-2).
- Arrival notifications are watched by iOS on the device, with no server involved (ARR-1).
- The map and the place search use Apple's map services, which receive the area shown or the text searched for (PLACE-2). In preparation for 1.4 naming a place sends Apple Maps the point under the pin, or where you are when the sheet opens (PLACE-10).

**Since:** 1.3
**Where:** `Cards/Core/Services/LocationService.swift`, `CardsWidget/WidgetLocation.swift`, `Cards/Core/Services/PlaceSearch+MapKit.swift`, `Cards/Features/ArrivalScheduler.swift`, `Cards/Core/Services/NotificationClient.swift`, `Website/src/privacy.html`

### PLAT-6: Know the camera is only used to scan

As a card holder, I want the camera used only when I am scanning a card, so that it is never on without me knowing.

- The camera only runs while the add form is showing (CARD-2), and stops when the form goes away or a code is read.
- The form asks for camera access before it starts the camera, and never starts it while access is off (CARD-2) (1.3).
- Frames are read on the device for barcodes and never recorded, stored or sent.

**Since:** 1.0
**Where:** `Cards/Scanner/ScannerViewControllerDelegate.swift`, `Cards/Scanner/CameraScannerView.swift:21-26`, `Cards/Scanner/CameraScannerView.swift:46-106`

### PLAT-7: Read the app in my language

As a card holder, I want the app in my own language, so that I understand every screen.

- The app speaks British English, and, in preparation for 1.4, Spanish (Spain), German and Japanese. It follows the language chosen for it in iOS Settings, or the device's language, and falls back to British English for any other.
- Every word on screen and every word VoiceOver speaks is translated, including the app's name under its icon, the permission prompts, the arrival notification, the Home Screen widget and its gallery entry, and What's New for 1.4 (SET-2). The user's own words, card names, codes and place names, are shown as typed.
- Dates, distances and radii follow the device's region: "1,5 km" in Germany, "400 yd" in the UK, "0.93 mi" in the US. Distances are spoken in full by VoiceOver ("350 metres", "350 Meter").
- Counts use each language's plural forms: "1 card", "2 cards"; Japanese has one form for every number.
- Card codes, version numbers and JSON read left to right in every language, and barcodes are never mirrored.
- An English device always shows English, never a translation, because `Info.plist` keeps `CFBundleDevelopmentRegion`.

**Since:** 1.0 (English), in preparation for 1.4 (Spanish, German and Japanese)
**Where:** `Cards/Localizable.xcstrings`, `Cards/InfoPlist.xcstrings`, `CardsWidget/Localizable.xcstrings`, `CardsWidget/InfoPlist.xcstrings`, `Cards.xcodeproj/project.pbxproj` (`knownRegions`), `CardsTests/LocalisationBundleTests.swift`, `CardsUITests/CardsLocalisationScreenshotTests.swift`
**Notes:** French, Italian, Arabic, Traditional Chinese, Brazilian Portuguese, Korean and Simplified Chinese were translated on the localisation branch and are held back for later waves; `l10n/context.md` says how to bring each back. The right-to-left layout that Arabic needs is built and tested with right to left forced (`CardsRightToLeftUITests`).

### PLAT-8: Find the app in the App Store in my language

As someone looking for a card wallet, I want the App Store listing in my language, so that I can tell what the app does before I download it.

- The listing has British English (en-GB), American English (en-US), Spanish for Spain (es-ES), Spanish for Mexico (es-MX), German (de-DE) and Japanese (ja) versions, in preparation for 1.4. Each one says the same thing in its own words, with the wording people search for there: "Fidelización" in Spain, "Cartera" in Mexico, "Kundenkarten" in Germany, "ポイントカード管理" in Japan.
- Every listing keeps the name "Card Barcodes" and localises the part after the colon, within 30 characters. Names, subtitles and screenshot captions never mention the price; the description and promotional text may say the app is free.
- Each listing has its own keywords, within 100 bytes, with no word already in its name or subtitle and no competitor's name.
- Each listing's What's New is that version's changelog in its language (SET-2), and its screenshots show the app in its language, with captions in it.
- App Review's notes are written once, in British English.

**Since:** In preparation for 1.4
**Where:** `metadata/<locale>/`, `screenshots/store/<locale>/captions.json`, `scripts/check-metadata.ts`, `scripts/check-store-images.ts`, `scripts/upload-metadata.ts`, `scripts/upload-screenshots.ts`
