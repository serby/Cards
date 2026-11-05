# Navigation

How the app is laid out and how other places, such as the widget and notifications, open a card in it.

### NAV-1: Move between my cards and the settings

As a card holder, I want the app split into my cards and its settings, so that the cards are always one tap away.

- The app has two tabs: Cards, with a barcode icon, and Settings, with a gear.
- The Cards tab opens on the list (CARD-1). Opening a card, editing it and adding one push screens on top of the list, with Back to return.
- Each time the Cards tab appears, it goes back to the list.
- The tab bar uses the pink accent (COL-7). On iOS 26 and later it minimises on scroll (`tabBarMinimizeBehavior(.onScrollUp)`).

**Since:** 1.0
**Where:** `Cards/App/CardsApp.swift:35-63`, `Cards/Core/Navigation/NavigationManager.swift`, `Cards/UI/Modifiers/ConditionalModifier.swift:18-25`, `CardsTests/NavigationTests.swift`
**Notes:** A link or a notification tap (NAV-2, ARR-2, WID-4) changes the Cards tab without selecting it. With Settings showing, the card opens on the Cards tab behind it, and since the Cards tab goes back to the list each time it appears, the card is gone by the time you switch to it (`Cards/App/CardsApp.swift:44-46`). Debug builds add a Storybook tab; release builds never have it.

### NAV-2: Open a card from a link

As a card holder, I want a link to open a card directly, so that the widget and notifications take me straight to it.

- `cards://cards/card/<code>` opens the card with that code. `cards://cards/card/<code>/edit` opens its edit form on top of it. `cards://cards/new` opens the add form.
- Each part of the path is percent-decoded on its own, so a code can hold "/", "?", "#", spaces, "%" or non-ASCII letters (1.3).
- Links the app builds percent-encode everything except ASCII letters, digits and `-._~` in each part (1.3).
- `cards://cards` and any path the app doesn't recognise open the list.
- A link with another scheme, another host or no host is ignored.
- A link to a code no card has shows "Card not found".
- Opening a link replaces whatever was showing on the Cards tab: a card link leaves the card on top of the list, and an edit link the edit form on top of the card.

**Since:** 1.0
**Where:** `Cards/Core/Navigation/NavigationRoute.swift`, `Cards/Core/Navigation/NavigationManager.swift`, `Cards/Features/CardListScreen.swift:60-94`, `Info.plist`, `CardsTests/NavigationTests.swift`
**Notes:** `NavigationRoute.path` gives "/cards/card/<code>", which `NavigationRoute.from(path:)` doesn't read back: it expects "/card/<code>". Only the tests use either (`Cards/Core/Navigation/NavigationRoute.swift:22-37`).
