# Development tools

What debug builds add for building and testing the app. None of it is in release builds (docs/DEVELOPMENT.md, rule 1).

### DEV-1: Find the development tools in one tab

As someone building the app, I want the development tools in one place, so that I can reach them without disturbing the app's own screens.

- Debug builds have a third tab, "Development", with a hammer icon, after Cards and Settings. Release builds have no such tab.
- The tab opens on a list titled "Development" with its tools under "Tools", each with a line saying what it does: Storybook, the story browser that used to be its own tab, and Test Notification (DEV-2).
- Storybook opens full screen over the tabs, with Done to close it, because its story list and stage are a split view that can't be pushed onto the tab's stack. Test Notification is pushed, with Back to return.
- The tab is hidden during UI tests (`-uiTesting` or `CARDS_UI_TESTING=1`), as the Storybook tab was.

**Since:** In preparation for 1.4
**Where:** `Cards/App/DevelopmentHooks.swift`, `Cards/Core/Navigation/AppTab.swift`, `Cards/Development/Tools/DevelopmentView.swift`, `Cards/Development/Storybook/StorybookView.swift`

### DEV-2: Send a test arrival notification

As someone building the app, I want to send an arrival notification for any card on demand, so that I can check how it looks and that tapping it opens the card, without travelling to a place.

- Development > Test Notification lists every card in the list's order, each with the place its notification names ("At Westway"). Tapping a card schedules its arrival notification (ARR-1) to arrive in five seconds, with the card's name as the title, its first place's name, or "Test" for a card with no places, as the place, and its barcode attached.
- After a tap the list's footer says "The notification for <card> arrives in 5 seconds.", and VoiceOver announces it. Each tap sends another.
- The notification is the same as a real one, and tapping it opens the card (ARR-2). It shows even while the app is open, because the app shows notifications in the foreground.
- It has an identifier of its own, so it never replaces the arrival watched at the card's place. It is sent whatever the Settings switch and the card's own switch say (ARR-5, ARR-6).
- The first tap asks for permission if the app never has (ARR-4). If notifications are off for the app, the tool shows "Notifications are off for Card Barcodes. Turn them on in Settings.", which opens the app's notification settings, and the tap sends nothing. It checks again on coming back to the app.
- With no cards it says "No Cards".

**Since:** In preparation for 1.4
**Where:** `Cards/Development/Tools/TestNotificationScreen.swift`, `Cards/Development/Tools/TestArrival.swift`, `Cards/Features/ArrivalPlan.swift`, `Cards/Core/Services/NotificationClient.swift`, `CardsTests/TestArrivalTests.swift`, `CardsTests/NotificationClientTests.swift`
**Notes:** Planning the arrivals again cancels every pending notification, so if the places to watch change in those five seconds, as they do when a card is added or edited, the test notification is cancelled too.
