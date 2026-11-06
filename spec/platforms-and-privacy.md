# Platforms and privacy

The devices and systems Card Barcodes runs on, the language it speaks, what it does and doesn't do with your data, and when it asks for a rating.

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

### PLAT-7: Read the app in English

As a card holder, I want the app's words in clear English, so that I understand every screen.

- The app's text is in British English, such as "Colour" and "Postcode", whatever the device's language.
- The App Store listing has British English (en-GB) and American English (en-US) versions that say the same thing.
- What's New shows American English text on devices in the US where the changelog has it (SET-2).

**Since:** 1.0
**Where:** `Cards/UI`, `metadata/en-GB`, `metadata/en-US`

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

**Since:** In preparation for 1.4
**Where:** `Cards/Core/Models/ReviewPrompt.swift`, `Cards/Core/Models/DeviceSettings.swift`, `Cards/Features/CardListScreen.swift`, `Cards/App/DevelopmentHooks.swift` (`asksForReviews`), `CardsTests/ReviewPromptTests.swift`
**Notes:** The card shown in full above the grid where you are (SET-3) is not counted, because it never opens a card's screen.
