# Development tools

What debug builds add for building and testing the app. None of it is in release builds (docs/DEVELOPMENT.md, rule 1).

### DEV-1: Find the development tools in one tab

As someone building the app, I want the development tools in one place, so that I can reach them without disturbing the app's own screens.

- Debug builds have a third tab, "Development", after Cards and Settings. Release builds have no such tab.
- The tab lists its tools: Storybook, which is the story browser that used to be its own tab, and Test Notification (DEV-2).
- The tab is hidden during UI tests, as the Storybook tab was.

**Since:** In preparation for 1.4
**Where:** `Cards/App/DevelopmentHooks.swift`, `Cards/Development/`

### DEV-2: Send a test arrival notification

As someone building the app, I want to send an arrival notification for any card on demand, so that I can check how it looks and that tapping it opens the card, without travelling to a place.

- Development > Test Notification lists every card. Tapping a card schedules its arrival notification (ARR-1) to arrive in five seconds, with the card's name as the title and its first place's name, or "Test", as the place.
- The notification is the same as a real one, and tapping it opens the card (ARR-2). It shows even while the app is open, because the app shows notifications in the foreground.
- If notifications are off for the app, the tool says so and offers to open Settings.

**Since:** In preparation for 1.4
**Where:** `Cards/Development/`, `Cards/Features/ArrivalPlan.swift`, `Cards/Core/Services/NotificationClient.swift`
