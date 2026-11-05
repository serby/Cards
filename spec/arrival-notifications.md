# Arrival notifications

When you arrive at one of a card's places, a notification reminds you, and tapping it opens the card. Each place is a location-triggered local notification that iOS watches itself: there is no background location, no server, and nothing runs while the app is closed. Each card can be switched off on its own, and the Settings switch turns them all off.

### ARR-1: Get a reminder when I arrive

As a card holder, I want a reminder when I reach the shop, so that I open the right card before I get to the till.

- Each place of each card (PLACE-1) is scheduled as a notification that fires when you enter its circle. Leaving the circle does nothing.
- It fires every time you enter, without needing to be scheduled again.
- The notification's title is the card's name and its text is "You're at <place>. Your barcode is ready."
- It plays the default notification sound.
- The app attaches the barcode to the notification as an image on white (BAR-2), but the barcode does not show on the Lock Screen: the notification appears as its title and text. A code that can't be drawn sends the notification without the attachment (BAR-3).
- Notifications for the same card are grouped together.
- While the app is open, an arrival still shows as a banner and in Notification Centre.
- The app schedules from the Cards list: the first time the list appears after launch, whenever the cards change, including a card's own switch (ARR-6), and as you move (ARR-3).
- Each time, it works out the places to watch. If they, or the card shown at any of them, have changed, it removes every scheduled arrival and schedules the current ones. Otherwise it leaves them as they are.
- Deleting a card, or removing a place, cancels its arrivals when the list next schedules.

**Since:** 1.3
**Where:** `Cards/Features/ArrivalNotifications.swift`, `Cards/Features/CardListScreen.swift:33-66`, `CardsTests/CardLocationTests.swift` (`ArrivalNotifierTests`)
**Notes:** Changes that reach a device through iCloud are only scheduled once the app is opened on it.

### ARR-2: Open the card from the notification

As a card holder, I want to tap the notification to open the card, so that I can show it full size.

- Tapping an arrival notification opens the app on that card's screen, found by its code (CARD-8).
- The tap brings the Cards tab forward, so the card shows even when Settings was open (NAV-1).
- The handler is set before launch finishes, so a tap that launches the app reaches it.
- If the card no longer exists, the screen says "Card not found".

**Since:** 1.3
**Where:** `Cards/Features/ArrivalNotifications.swift:134-164`, `Cards/App/CardsApp.swift:13-21`, `Cards/Core/Navigation/NavigationManager.swift`, `CardsTests/CardFixesTests.swift` (`openingACardBringsTheCardsTabForward`)

### ARR-3: Watch the places nearest to me when I have many

As a card holder with many places, I want the app to watch the places I am most likely to reach, so that the limit iOS sets doesn't lose the ones that matter.

- iOS watches at most 20 regions for an app, so at most 20 places are scheduled.
- When the app knows where you are as it schedules, it keeps the 20 places nearest to you, by distance to the edge of each circle.
- When it doesn't, it keeps the first 20 in list order: the cards from the top, each card's places in the order they were added.
- Cards without places, and cards switched off (ARR-6), are never scheduled and take none of the 20.
- While the app is open, the list works out the places again when your location first arrives and each time you move into a new area of about a kilometre: a hundredth of a degree of latitude by a hundredth of a degree of longitude.
- The scheduled arrivals are only replaced when the places to watch change, so with 20 places or fewer moving changes nothing. With more than 20, the nearest 20 are watched once the app has a location.

**Since:** 1.3
**Where:** `Cards/Features/ArrivalNotifications.swift:39-95`, `Cards/Features/CardListScreen.swift:33-39`, `CardsTests/CardLocationTests.swift` (`nearestLocationsAreKeptWithinTheRegionLimit`, `everyLocationOfEveryCardIsWatched`, `cardsWithoutLocationsAreNotWatched`), `CardsTests/CardFixesTests.swift` (`theNearestPlacesAreWatchedOnceThereIsALocation`, `movingAboutAKilometreChangesTheArea`, `cardsSwitchedOffAreNotWatched`)
**Notes:** The app only follows your location while it is in use (PLACE-6), so the places are only chosen again while it is open. Once it is closed, iOS keeps watching the places chosen last, wherever you go.

### ARR-4: Be asked before the app sends notifications

As a card holder, I want the app to ask before it sends notifications, and only when it has something to send, so that I am not asked for no reason.

- The app asks for notification permission the first time it schedules arrivals, which is when the list opens with at least one card that has a place and its own switch on (ARR-6), and the Settings switch on.
- If permission is refused, nothing is scheduled. Settings says so and links to the system settings (ARR-5).
- Arrivals also need location permission (PLACE-7).

**Since:** 1.3
**Where:** `Cards/Features/ArrivalNotifications.swift:47-66`, `CardsUITests/CardsUITests.swift` (`dismissNotificationPrompt`)

### ARR-5: Turn arrival notifications off and on

As a card holder, I want a switch for arrival notifications, so that I can stop them without removing my places.

- Settings has an Arrival Notifications switch in the Locations section, captioned "Reminds you when you arrive at one of a card's places. To stop one card reminding you, turn off Notify When I Arrive when you edit it."
- It is on by default, and the setting is kept on the device.
- It covers every card. While it is off, no card reminds you, whatever its own switch says, and each card's switch is greyed out in its edit form (ARR-6).
- Turning it off cancels every scheduled arrival. Turning it on schedules again the cards whose own switch is on. Both go through the Cards list's scheduling (ARR-1).
- Distances and the widget carry on working with it off.
- When the switch is on and notifications are turned off for the app in the Settings app, Settings shows "Notifications are off for Card Barcodes. Turn them on in Settings." with a crossed-out bell. Tapping it opens the app's notification settings.
- That check runs again each time the app comes back to the foreground.

**Since:** 1.3
**Where:** `Cards/UI/Screens/SettingsListView.swift`, `Cards/Features/SettingsScreen.swift`, `Cards/Features/CardListScreen.swift:45-50`, `CardsUITests/CardsUITests.swift` (`testArrivalNotificationsSwitch`)
**Notes:** The message only shows once notifications have been refused. Before the app has asked, there is nothing to show.

### ARR-6: Stop one card reminding me

As a card holder, I want to turn arrival notifications off for one card, so that I keep its places for distances and the widget without being reminded there.

- In the edit form, the Locations section has a "Notify When I Arrive" switch below the card's places and above "Add Location".
- The switch only shows while the card has at least one place, counting places added in the form before it is saved.
- It is on for every card unless turned off, including cards saved before the switch existed and cards imported from older exports (DATA-4).
- The choice is saved with the card when the form is saved, and syncs and exports with it (DATA-1, DATA-2).
- A card that is switched off is never scheduled (ARR-1), and its places don't count towards the 20 (ARR-3).
- While the Settings switch is off (ARR-5), the card's switch is greyed out and can't be changed. It keeps the card's choice for when Settings is turned back on.
- The Locations footer says what will happen, and changes as the form does. With no places it reads "Add a place to be reminded when you arrive there."
- With places and the Settings switch off, the footer reads "Arrival notifications are off for every card in Settings."
- With places and the card switched on, it reads "When you arrive at one of these places, a notification reminds you. Tap it to open the card."
- With places and the card switched off, it reads "This card won't remind you when you arrive."
- The switch only affects arrival notifications. Distances (PLACE-6) and the widget (WID-1) still use the card's places.

**Since:** 1.3
**Where:** `Cards/UI/Screens/CardEditView.swift:112-136`, `Cards/UI/Screens/CardEditView.swift:168-180`, `Cards/Features/CardEditScreen.swift`, `Cards/UI/ViewState/CardViewState.swift`, `Cards/Core/Models/CardItem.swift`, `Cards/Features/ArrivalNotifications.swift:85-95`, `Cards/Features/CardListScreen.swift:56-66`, `CardsTests/CardFixesTests.swift` (`cardsSwitchedOffAreNotWatched`, `notifyingIsKeptAndOlderExportsNotify`)
**Notes:** Removing a card's last place in the form hides the switch, but the card keeps its choice, so the switch comes back as it was when a place is added again.
