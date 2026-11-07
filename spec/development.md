# Development tools

What debug builds add for building and testing the app. None of it is in release builds (docs/DEVELOPMENT.md, rule 1).

### DEV-1: Find the development tools in one tab

As someone building the app, I want the development tools in one place, so that I can reach them without disturbing the app's own screens.

- Debug builds have a third tab, "Development", with a hammer icon, after Cards and Settings. Release builds have no such tab.
- The tab opens on a list titled "Development" with its tools under "Tools", each with a line saying what it does: Storybook, the story browser that used to be its own tab, Test Notification (DEV-2), Review Prompt (DEV-3) and Language (DEV-4).
- Storybook opens full screen over the tabs, with Done to close it, because its story list and stage are a split view that can't be pushed onto the tab's stack. Test Notification, Review Prompt and Language are pushed, with Back to return.
- The tab is hidden during UI tests (`-uiTesting` or `CARDS_UI_TESTING=1`), as the Storybook tab was.

**Since:** In preparation for 1.4
**Where:** `Cards/App/DevelopmentHooks.swift`, `Cards/Core/Navigation/AppTab.swift`, `Cards/Development/Tools/DevelopmentView.swift`, `Cards/Development/Storybook/StorybookView.swift`

### DEV-2: Send a test arrival notification

As someone building the app, I want to send an arrival notification for any card on demand, so that I can check how it looks and that tapping it opens the card, without travelling to a place.

- Development > Test Notification lists every card in the list's order, each with the place its notification names ("At Boulder Barn"). Tapping a card schedules its arrival notification (ARR-1) to arrive in five seconds, with the card's name as the title, its first place's name, or "Test" for a card with no places, as the place, and its barcode attached.
- After a tap the list's footer says "The notification for <card> arrives in 5 seconds.", and VoiceOver announces it. Each tap sends another.
- The notification is the same as a real one, and tapping it opens the card (ARR-2). It shows even while the app is open, because the app shows notifications in the foreground.
- It has an identifier of its own, so it never replaces the arrival watched at the card's place. It is sent whatever the Settings switch and the card's own switch say (ARR-5, ARR-6).
- The first tap asks for permission if the app never has (ARR-4). If notifications are off for the app, the tool shows "Notifications are off for Card Barcodes. Turn them on in Settings.", which opens the app's notification settings, and the tap sends nothing. It checks again on coming back to the app.
- With no cards it says "No Cards".

**Since:** In preparation for 1.4
**Where:** `Cards/Development/Tools/TestNotificationScreen.swift`, `Cards/Development/Tools/TestArrival.swift`, `Cards/Features/ArrivalPlan.swift`, `Cards/Core/Services/NotificationClient.swift`, `CardsTests/TestArrivalTests.swift`, `CardsTests/NotificationClientTests.swift`
**Notes:** Planning the arrivals again cancels every pending notification, so if the places to watch change in those five seconds, as they do when a card is added or edited, the test notification is cancelled too.

### DEV-3: Check the review prompt

As someone building the app, I want to see what the review prompt has counted and to ask for a rating on demand, so that I can check Apple's prompt and the rule without waiting three days.

- Development > Review Prompt shows what PLAT-8 has counted on this device: the version counted ("None" before any card is opened), "Days With a Card Shown" as "2 of 3", when a card was last shown ("Never" before), whether the app has asked in that version, and whether it is due.
- "Ask for a Rating Now" asks straight away and leaves the counts as they are. A debug build shows Apple's prompt on every request, including on the simulator.
- "Make It Due" counts three days in the current version, so the next time you come back from a card to the list the app asks, as it would on the third day.
- "Start Again" clears the counts, as on a new install.
- After each button the section's footer says what it did, and VoiceOver announces it.

**Since:** In preparation for 1.4
**Where:** `Cards/Development/Tools/ReviewPromptScreen.swift`, `Cards/Development/Tools/DevelopmentView.swift`, `Cards/Core/Models/ReviewPrompt.swift`

### DEV-4: Open the app in another language

As someone building the app, I want to open the app in any of its languages from the app itself, so that I can check a translation on the screen it is on without changing the iPhone's language or relaunching from Xcode.

- Development > Language lists System first, then every language in the app bundle: today English, Deutsch, 日本語 and Español. Each is named in its own language, with its English name under it ("German"); English, whose two names are the same, has no second line, and System says "The iPhone's language". The one in effect is ticked, and VoiceOver reads it as selected.
- Choosing another asks "Open in Deutsch?": "Card Barcodes closes so it can open in Deutsch. Open it again from the Home Screen." Close Card Barcodes sets the app's own language, the `AppleLanguages` default in its own domain, to that language and quits; Cancel changes nothing. Choosing the one already ticked does nothing.
- System removes the app's own language, so it opens in the iPhone's language again.
- Only the language changes. The region stays as it is, so distances on Automatic keep their units, and dates and times keep the region's clock and calendar. The footer says so.
- The Home Screen widget stays in the iPhone's language, as it runs in a process of its own with its own defaults. The footer says so.

**Since:** In preparation for 1.4
**Where:** `Cards/Development/Tools/LanguageScreen.swift`, `Cards/Development/Tools/LanguageChoice.swift`, `Cards/Development/Tools/AppLanguageClient.swift`, `Cards/Development/Storybook/Catalogue/DevelopmentStories.swift`, `CardsTests/LanguageToolTests.swift`
**Notes:** A language given at launch, by the scheme's App Language or `-AppleLanguages`, wins over the one chosen here while it is given, and the tool still ticks the one chosen here. The language list is the Storybook's (`StoryLanguage`), so a newly translated language appears in both with no code change. The bundle has one English, the British source, so there is no separate English (US): American wording in What's New follows the region, which this tool leaves alone.
