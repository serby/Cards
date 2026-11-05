# Arrival notifications

When you arrive at one of a card's places, its barcode appears on your Lock Screen. Each place is a location-triggered local notification that iOS watches itself: there is no background location, no server, and nothing runs while the app is closed.

### ARR-1: See the barcode on my Lock Screen when I arrive

As a card holder, I want the right card's barcode to appear when I reach the shop, so that it is ready before I get to the till.

- Each place of each card (PLACE-1) is scheduled as a notification that fires when you enter its circle. Leaving the circle does nothing.
- It fires every time you enter, without needing to be scheduled again.
- The notification's title is the card's name and its text is "You're at <place>. Your barcode is ready."
- It carries the barcode as an image on white with a quiet zone, ready to scan (BAR-2). A code that can't be drawn sends the notification without the image (BAR-3).
- Notifications for the same card are grouped together.
- While the app is open, an arrival still shows as a banner and in Notification Centre.
- The app schedules from the Cards list: the first time the list appears after launch, and whenever a card's name, code, barcode type or places change, it removes every scheduled arrival and schedules the current ones (ARR-3).
- Deleting a card, or removing a place, cancels its arrivals when the list next schedules.

**Since:** 1.3
**Where:** `Cards/Features/ArrivalNotifications.swift`, `Cards/Features/CardListScreen.swift:33-58`, `CardsTests/CardLocationTests.swift` (`ArrivalNotifierTests`)
**Notes:** The notifications have no sound. The app asks for permission to play sounds, but sets none on the notification (`Cards/Features/ArrivalNotifications.swift:55`, `:84-92`). Changes that reach a device through iCloud are only scheduled once the app is opened on it.

### ARR-2: Open the card from the notification

As a card holder, I want to tap the notification to open the card, so that I can show it full size.

- Tapping an arrival notification opens the app on that card's screen, found by its code (CARD-8).
- The handler is set before launch finishes, so a tap that launches the app reaches it.
- If the card no longer exists, the screen says "Card not found".

**Since:** 1.3
**Where:** `Cards/Features/ArrivalNotifications.swift:119-149`, `Cards/App/CardsApp.swift:13-21`
**Notes:** The tap doesn't switch tabs. With Settings showing, the card opens on the Cards tab behind it (NAV-1).

### ARR-3: Watch the places nearest to me when I have many

As a card holder with many places, I want the app to watch the places I am most likely to reach, so that the limit iOS sets doesn't lose the ones that matter.

- iOS watches at most 20 regions for an app, so at most 20 places are scheduled.
- When the app knows where you are as it schedules, it keeps the 20 places nearest to you, by distance to the edge of each circle.
- When it doesn't, it keeps the first 20 in list order: the cards from the top, each card's places in the order they were added.
- Cards without places are never scheduled.

**Since:** 1.3
**Where:** `Cards/Features/ArrivalNotifications.swift:36-81`, `CardsTests/CardLocationTests.swift` (`nearestLocationsAreKeptWithinTheRegionLimit`, `everyLocationOfEveryCardIsWatched`, `cardsWithoutLocationsAreNotWatched`)
**Notes:** The choice is only made again when the watched cards change or the app launches again; moving doesn't change it. The first schedule after launch always runs before the app has a location fix, so with more than 20 places the first 20 in list order are kept until a card changes (`Cards/Features/CardListScreen.swift:33-38`, `Cards/Features/ArrivalNotifications.swift:47`).

### ARR-4: Be asked before the app sends notifications

As a card holder, I want the app to ask before it sends notifications, and only when it has something to send, so that I am not asked for no reason.

- The app asks for notification permission the first time it schedules arrivals, which is when the list opens with at least one card that has a place and the Settings switch on.
- If permission is refused, nothing is scheduled. Settings says so and links to the system settings (ARR-5).
- Arrivals also need location permission (PLACE-7).

**Since:** 1.3
**Where:** `Cards/Features/ArrivalNotifications.swift:46-67`, `CardsUITests/CardsUITests.swift` (`dismissNotificationPrompt`)

### ARR-5: Turn arrival notifications off and on

As a card holder, I want a switch for arrival notifications, so that I can stop them without removing my places.

- Settings has an Arrival Notifications switch in the Locations section, captioned "Shows a card's barcode on your Lock Screen when you arrive at one of its places".
- It is on by default, and the setting is kept on the device.
- Turning it off cancels every scheduled arrival. Turning it on schedules them again. Both go through the Cards list's scheduling (ARR-1).
- Distances and the widget carry on working with it off.
- When the switch is on and notifications are turned off for the app in the Settings app, Settings shows "Notifications are off for Card Barcodes. Turn them on in Settings." with a crossed-out bell. Tapping it opens the app's notification settings.
- That check runs again each time the app comes back to the foreground.

**Since:** 1.3
**Where:** `Cards/UI/Screens/SettingsListView.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/Features/CardListScreen.swift:44-48`, `CardsUITests/CardsUITests.swift` (`testArrivalNotificationsSwitch`)
**Notes:** The message only shows once notifications have been refused. Before the app has asked, there is nothing to show.
