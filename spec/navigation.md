# Navigation

How the app is laid out and how other places, such as the widget and notifications, open a card in it.

### NAV-1: Move between my cards and the settings

As a card holder, I want the app split into my cards and its settings, so that the cards are always one tap away.

- The app has two tabs: Cards, with a barcode icon, and Settings, with a gear.
- The Cards tab opens on the list (CARD-1). Opening a card, editing it and adding one push screens on top of the list, with Back to return.
- The Cards tab keeps its place when you switch tabs, so a card left open is still open when you come back (1.3).
- Opening a card from a link, the widget or a notification brings the Cards tab forward, so it shows even when Settings was open (NAV-2, WID-4, ARR-2) (1.3).
- In preparation for 1.5: opening an export in the app from Files, Mail or AirDrop brings the Settings tab forward instead, to import it, and the Cards tab keeps its place (DATA-11).
- The tab bar uses the pink accent (COL-7). It is iOS's own and always in view: it never minimises on scroll (in preparation for 1.4).

**Since:** 1.0
**Where:** `Cards/App/CardsApp.swift`, `Cards/Core/Navigation/NavigationManager.swift`, `Cards/Core/Navigation/AppTab.swift`, `Cards/UI/Modifiers/ConditionalModifier.swift:18-25`, `CardsTests/NavigationTests.swift`, `CardsTests/CardFixesTests.swift` (`openingACardBringsTheCardsTabForward`)
**Notes:** Debug builds add a third tab; release builds never have it. Since 1.4 it is the Development tab, with a hammer icon, which holds the Storybook and the other development tools (DEV-1); before, it was the Storybook tab. Before 1.3 the Cards tab went back to the list each time it appeared, and a link or notification opened the card behind Settings without selecting the Cards tab.

### NAV-2: Open a card from a link

As a card holder, I want a link to open a card directly, so that the widget and notifications take me straight to it.

- `cards://cards/card/<code>` opens the card with that code. `cards://cards/card/<code>/edit` opens its edit form on top of it. `cards://cards/new` opens the add form.
- Each part of the path is percent-decoded on its own, so a code can hold "/", "?", "#", spaces, "%" or non-ASCII letters (1.3).
- Links the app builds percent-encode everything except ASCII letters, digits and `-._~` in each part (1.3).
- `cards://cards` and any path the app doesn't recognise open the list.
- A link with another scheme, another host or no host is ignored.
- A link to a code no card has shows "Card not found".
- Opening a link replaces whatever was showing on the Cards tab: a card link leaves the card on top of the list, and an edit link the edit form on top of the card.
- Every link the app reads selects the Cards tab, from Settings too (NAV-1) (1.3).
- Since 1.4: share links, `https://cards.serby.net/add#…` (a universal link) and `cards://cards/add#…`, ask whether to add the card in them (SHARE-3). They show a sheet over the Cards tab instead of replacing what it shows. Other `https` links, and `https://cards.serby.net` links to any other page, are ignored.

**Since:** 1.0
**Where:** `Cards/Core/Navigation/NavigationRoute.swift`, `Cards/Core/Navigation/NavigationManager.swift`, `Cards/Features/CardListScreen.swift`, `Info.plist`, `CardsTests/NavigationTests.swift`, `CardsTests/CardFixesTests.swift` (`openingACardBringsTheCardsTabForward`), `Cards/Core/Navigation/SharedCardLink.swift`, `Cards/App/CardsApp.swift`
**Notes:** `NavigationRoute.path` gives "/cards/card/<code>", which `NavigationRoute.from(path:)` doesn't read back: it expects "/card/<code>". Only the tests use either (`Cards/Core/Navigation/NavigationRoute.swift:22-37`).
