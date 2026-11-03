# Cards development guide

How to build, change and ship Cards. It is written for people and for coding agents alike: the numbered rules in [section 4](#4-rules) are the contract every change is held to, and the recipes in [section 5](#5-recipes) show how to follow them for the common jobs.

If something here turns out to be wrong, fix the guide in the same change.

## Contents

1. [Set up](#1-set-up)
2. [The everyday loop](#2-the-everyday-loop)
3. [Project layout](#3-project-layout)
4. [Rules](#4-rules)
5. [Recipes](#5-recipes)
6. [Running and driving the simulator](#6-running-and-driving-the-simulator)
7. [Signing, teams and iCloud](#7-signing-teams-and-icloud)
8. [Releasing](#8-releasing)
9. [Troubleshooting](#9-troubleshooting)

## 1. Set up

| Tool | Why | Notes |
|------|-----|-------|
| Xcode 27.1 | Builds, tests, simulators | The Makefile expects `/Applications/Xcode27.1.app`; override with `make XCODE_APP=/path/to/Xcode.app …` |
| SwiftLint | Lint, run before every build | `.swiftlint.yml` at the root |
| Node 24 | `scripts/check-release-clean.ts`, `scripts/l10n.ts` | Runs TypeScript directly, no install step |
| Claude Code | `make l10n-translate` | The default AI for translations; any other command can stand in through `L10N_AI_COMMAND` |
| Python 3 | `scripts/validate-screenshots.py` | Ships with macOS |
| librsvg, ImageMagick | App icon rendering only | `brew install librsvg imagemagick` |

Open the project with `open Cards.xcodeproj`. There is no generator step: the project is checked in, and the app target reads every file under `Cards/` through a file system synchronised group, so a new file or folder on disk is in the build with nothing to add.

The deployment target is iOS 18.0. The app is built with the iOS 27 SDK, so anything newer than iOS 18 must sit behind `if #available` (see `tabBarMinimizeBehaviorIfAvailable()` for the pattern).

## 2. The everyday loop

Run these in order after every change, and fix what fails before moving on:

1. `swiftlint lint`
2. `make build`
3. `make test`, or `make test-unit` while iterating on logic
4. `make check-release` whenever you add or move code in `Cards/Development`, touch `Cards/App/DevelopmentHooks.swift`, or add a preview
5. `make capture-screenshots` whenever the list, the Add Card form or Settings change, then look at every changed PNG before committing it

| Command | What it does |
|---------|-------------|
| `make build` | Build the app (Debug) for the simulator |
| `make test` | Unit and UI tests |
| `make test-unit` | `CardsTests` only |
| `make test-e2e` | `CardsUITests` only |
| `make test-a11y` | The accessibility audit on every screen, in English and in Arabic at the largest text size |
| `make test-tsan` | Unit tests under the thread sanitiser |
| `make test-coverage` | Tests plus an HTML coverage report in `coverage-html/` |
| `make check-release` | Build Release and fail if any development code reached it ([rule 1](#rule-1-development-code-never-ships)) |
| `make sim` | Build, boot the simulator, install and launch |
| `make device` | Build and install on a connected iPhone |
| `make capture-screenshots` | Refresh the en-US and en-GB iPhone and iPad App Store screenshots |
| `make validate-screenshots` | Check the committed screenshot set |
| `make deploy-testflight`, `make deploy-appstore` | Archive, export and upload |
| `make l10n-status`, `make l10n-check` | Translation counts per catalogue and language; fail if any language is incomplete |
| `make l10n-translate` | Translate the String Catalogues with AI (`LANGS="ja fr"` for some languages only) |
| `make capture-l10n` | Screenshot every screen in every language at the default and largest text sizes, for checking translations by eye ([recipe](#check-the-translations-on-screen)) |

Override `SIMULATOR_DEVICE` and `SIMULATOR_VERSION` on the command line to target another simulator.

Xcode on this project writes build products to `fastlane/derived_data/Build/Products` (a custom build location preference), not to `-derivedDataPath`. Never guess the path; ask: `xcodebuild -project Cards.xcodeproj -scheme Cards -showBuildSettings | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p'`.

## 3. Project layout

One app target, one Swift module. The folders are layers by convention, so the compiler will not stop a violation; the rules in section 4 do.

```
Cards/
  App/           Entry point, and DevelopmentHooks: the only door into Development
  Core/          Models, navigation and services. No SwiftUI views
    Models/        CardItem (SwiftData), CardItemDTO, BarcodeType, CardColor, CardLocation
    Navigation/    NavigationRoute, NavigationManager, deep links
    Services/      LocationService, PostcodeLookup, PerformanceTracker
  UI/            Every view, as a pure function of view state and actions
    Screens/       CardListView, CardDetailView, CardEditView, LocationPickerView, SettingsListView
    Components/    BarcodeView, BarcodeImage, CardColorPicker, CardLocationRow, ProximityLabel, …
    ViewState/     CardSummary, CardDetail, CardDraft, SettingsState
    Actions/       Closure bundles each screen raises
    Environment/   Injected effects: ScreenBrightness, AccessibilityAnnouncer
    Theme/         Colours, the card palette
  Scanner/       Camera scanning (AVFoundation), pinch to zoom
  Features/      Connectors: SwiftData, navigation, location and notifications in, view state out
  Development/   Never in a release build. Storybook, previews, sample data, stand-ins, test seeds
CardsTests/      Unit tests (Swift Testing)
CardsUITests/    UI and screenshot tests (XCTest)
```

Dependencies point one way:

```
App ──▶ Features ──▶ UI ──▶ Core
              └────▶ Core
Development ──▶ anything          (nothing in production ──▶ Development, except DevelopmentHooks)
```

## 4. Rules

### Rule 1: Development code never ships

Development code is anything that exists to build, preview, test or demonstrate the app rather than to run it: the Storybook, `#Preview` blocks, sample data and fixtures, simulated effects (`ScreenBrightness.simulated`, `AccessibilityAnnouncer.silent`), stand-in views (`ScannerPlaceholderView`), UI-test switches and screenshot seed data, and debugging aids (`Loader`). None of it may reach a release build, and none of it may clutter production code with `#if DEBUG`.

1. **It lives in `Cards/Development/`.** The Release configuration of the `Cards` target excludes that folder (`EXCLUDED_SOURCE_FILE_NAMES`), so files there are plain Swift with no `#if DEBUG` of their own. The patterns cover three folder levels below `Cards/Development`; add a pattern in the project if you ever need a fourth.
2. **Previews live in `Cards/Development/Previews/<View>+Previews.swift`,** not beside the view. Release builds type-check `#Preview` bodies even though they strip them, so a preview next to a view would drag sample data into the release compile. Open the previews file next to the view in Xcode to get the canvas, or use the Storybook.
3. **Production code reaches development code only through `Cards/App/DevelopmentHooks.swift`.** Each hook is one function or property whose body holds the `#if DEBUG` and returns something inert in release (`false`, nothing, an empty view). Call sites never contain `#if DEBUG`.
4. **`#if DEBUG` appears nowhere else.** `grep -rn "#if DEBUG" Cards` must only list `DevelopmentHooks.swift`.
5. **It is enforced.** A release build fails to compile if production code names anything in `Cards/Development` directly. On top of that, `make check-release` (and CI) builds Release and fails if any type or static member declared in `Cards/Development`, any SwiftUI preview, or a UI-testing launch key is in the binary.

A hook looks like this; the caller just writes `DevelopmentHooks.isUITesting`:

```swift
static var isUITesting: Bool {
    #if DEBUG
    CommandLine.arguments.contains("-uiTesting")
        || ProcessInfo.processInfo.environment["CARDS_UI_TESTING"] == "1"
    #else
    false
    #endif
}
```

Why: the shipped app carries no test-only behaviour switches, no fixtures and no tooling, so there is less to review and nothing that can be triggered by accident; production files read as production code.

### Rule 2: Views are pure

Views in `Cards/UI` never touch SwiftData, the camera, location, notifications, the pasteboard or screen brightness. Each view is a function of:

- **View state** (`UI/ViewState`): plain `Sendable` value types such as `CardSummary` and `CardDetail`. Add a field here, with a default, rather than passing a model object.
- **Actions** (`UI/Actions`): structs of closures, every one defaulting to a no-op, so a story or preview supplies only what it exercises.
- **Injected effects** (`UI/Environment`): environment values whose default is the real thing (`.system`). Stories and previews swap in the substitutes from `Cards/Development/SimulatedEffects.swift`, so a story can never change the device's brightness or speak with VoiceOver.
- **View slots** for anything device-bound: `CardEditView` is generic over its scanner, so the app passes the camera and stories pass `ScannerPlaceholderView`.

If a view needs a new capability, add an action or an injected effect; never reach for a singleton or `@Environment(\.modelContext)` inside `Cards/UI`.

### Rule 3: Impure work lives in connectors and services

`Cards/Features` holds one connector per screen (`CardListScreen`, `CardDetailScreen`, `CardEditScreen`, `SettingsScreen`). A connector reads `@Query`, `modelContext`, `NavigationManager` and `LocationService`, maps models to view state, and wires actions back to effects. Long-lived device services (`LocationService`) live in `Core/Services` and are injected with `.environment` from `CardsApp`; integration glue that also needs UI code (`ArrivalNotifier`, which renders barcodes) lives in `Features`.

Keep the logic of a service testable without the device: `ArrivalNotifier.plan` is a pure function, and the tests cover it rather than `UNUserNotificationCenter`.

### Rule 4: Every view has a story, and every parameter has a knob

Every view in `Cards/UI` has a story in `Cards/Development/Storybook/Catalogue`, and every parameter of that view has a knob. Use the knob kinds in `Story.swift` (toggle, text, number, options) and give the story a gallery of the fixed variants worth eyeballing.

- Screens set `galleryLayout: .oneAtATime`. SwiftUI puts every visible screen's toolbar items in the Storybook's one navigation bar, so a list of screens would show one Edit button per variant.
- Reuse the shared knobs rather than inventing new names: `ProximityKnobs` for anything that shows a distance.
- Bindings to local state go through `Stateful`; bindings to knobs through `KnobValues.*Binding`.
- A value read once at creation (a map's starting camera) needs `.id(knobValue)` so the story rebuilds when the knob changes.
- Each story's toolbar has a display options menu: appearance, text size, language and direction, applied to whichever story is on screen in either mode. Language offers System and every localisation compiled into the app, so a language appears as soon as it has a translation. Direction is Automatic (the language's script direction), Left to right or Right to left. The language and direction persist between launches in their own defaults suite, `net.serby.Cards.Storybook`, which the app never reads.
- The language sets the stage's `\.locale`, so it switches whatever SwiftUI resolves as it renders: `Text` and `Label` from a key or a `LocalizedStringResource`, prompts, picker items, the titles, messages and `Text` buttons of alerts and dialogs, sheets, `FormatStyle`s in a `Text` or a key's interpolation, and SwiftUI's own copy (`EditButton`, `DatePicker`). It cannot switch what is resolved before SwiftUI sees it or drawn by UIKit: `String(localized:)` (VoiceOver announcements, notifications, import results), `.formatted()` strings, the OK and Cancel buttons iOS adds to alerts and dialogs, and the keyboard. A sheet takes the language but keeps the app's direction. Check those by running the app in the language: the scheme's App Language, or launch with `-AppleLanguages '(de)'`.

### Rule 5: Colours come from the palette and must stay readable

Card faces use only `CardColor` swatches (`UI/Theme/CardPalette.swift`), each a fixed background with an ink. Never draw a card in an arbitrary colour. `CardColorTests` checks WCAG AA (4.5:1), in light and dark mode, for primary and secondary text on every card face (`.standard` included), for the name and distance on every tinted list row, for `Color.secondaryText` on every surface it is drawn on, for the text on the white barcode plate, and for the accent on the system and secondary backgrounds. It resolves the colours the views actually use (`CardColor.cardFill`, `primaryInk`, `secondaryInk`, `rowFill`, `rowInk`), so system colours are measured too. Adding a colour means adding a case, a swatch and a display name; the tests then cover it automatically. If a test fails, change the colour, never the threshold.

- Draw supporting text in `Color.secondaryText`, not the system's `.secondary`, `secondaryLabel` or `tertiaryLabel`, which measure 1.7 to 3.4:1 on white. New text on a new surface gets a line in `secondaryTextIsReadableOnEverySurface`.

### Rule 6: Models stay CloudKit- and export-compatible

The SwiftData store syncs through CloudKit, and users keep JSON exports. So:

- Every `@Model` property has a default value; no unique constraints; relationships optional.
- Enums are stored by raw value with a tolerant reader (`CardColor.stored(_:)`, `CardItem.getBarcodeType()`), so an unknown value from a newer build falls back instead of failing.
- New `CardItemDTO` fields are optional, and a test decodes an export from before the field existed.
- Persisting a new kind of value gets a round-trip test through a real in-memory `ModelContainer` (`cloudKitDatabase: .none`).
- Before a build with new fields ships, the CloudKit schema must be deployed to Production (see [section 8](#8-releasing)).

### Rule 7: Swift 6, no warnings, clean lint

The target builds in Swift 6 language mode with strict concurrency, `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `ExistentialAny`. Patterns that keep it clean:

- UI-facing services are `@MainActor`; delegate callbacks from Apple frameworks are `nonisolated` and hop back with `MainActor.assumeIsolated` when the framework calls on the main thread.
- Keep non-`Sendable` framework values inside the function that made them; return your own `Sendable` struct (`PlaceMatch`) instead.
- With several closures, use labelled closure arguments, not trailing closure syntax.
- Silence a lint rule only on the line that needs it, with `// swiftlint:disable:next rule_name` and a comment saying why.
- Never update `Map` content from `onMapCameraChange`: MapKit re-applies the camera and loops. Draw camera-relative overlays in screen space, as `LocationPickerView` does with its radius ring.

### Rule 8: Accessibility is part of done

- Every control a UI test touches has an `accessibilityIdentifier`; every meaningful control has a label in plain words.
- Never put an identifier on a `Section` or a `Form`: it replaces the identifier of every control inside.
- When something changes without a new screen (a scan, a search, a delete), say so through the injected `accessibilityAnnouncer`, with the message in `Announcements` if a view shares it. Never announce on appearing, which cuts across VoiceOver reading the screen; move focus with `@AccessibilityFocusState` instead, as the card screen does to its name.
- Nothing needs a gesture: whatever a swipe, drag or pinch does is also a context menu item or a named accessibility action (`accessibilityActions`), as the card list's Move Up, Move Down and Delete are. Controls never hide while assistive technology may need them.
- UI tests find elements by identifier, or tabs by position, never by their text, so they pass in any language. `CardsArabicUITests` runs `CardsUITests` again right to left. A language with no translation runs in English, left to right, so a right-to-left run also passes `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`.
- Decorative images are hidden from VoiceOver; codes are read character by character (`speechSpellsOutCharacters()`).
- Barcodes, card faces and colour swatches take `.keepsColoursWhenInverted()`, so Smart Invert leaves a barcode scannable and a red card red. `SmartInvertTests` checks they keep it.
- Layouts survive the accessibility text sizes: switch from side by side to stacked with `AnyLayout` when `dynamicTypeSize.isAccessibilitySize`, with no `Spacer` inside the `AnyLayout` (it does not know its axis there). A screen whose content can outgrow the display scrolls; text fields take `axis: .vertical` with a `.singleLine()` binding so long text wraps; a symbol's column or a swatch grows with `@ScaledMetric`.
- Every tappable thing is at least 44 by 44 pt, including what VoiceOver alone acts on, such as the map pin.
- Speech gets words, not abbreviations: format a distance or radius in an accessibility label with `.spokenDistance` or `.spokenRadius` ("350 metres"), and a value shown as "350 m" with `.distance` or `.radius`.
- Large movements honour `accessibilityReduceMotion`: animate them with `nil` when it is on.
- With Increase Contrast (`colorSchemeContrast == .increased`) secondary ink becomes primary, rows, cards and cells get an edge, and the app's own colours take their stronger variant (`Color(lightRGB:darkRGB:increasedLightRGB:increasedDarkRGB:)`).
- Main actions have keyboard shortcuts: ⌘N adds a card, ⌘E edits, ⌘S saves, ⌘Return confirms a sheet and Escape cancels it; Return moves to the next field.
- `CardsAccessibilityAuditTests` runs Xcode's accessibility audit (`performAccessibilityAudit`) on every screen, and `CardsArabicLargeTextAuditTests` again in Arabic, right to left, at the largest text size (`make test-a11y`, or part of `make test`). A new screen gets a test in both. Fix what it finds; add to `isKnownFalsePositive` only an issue you have confirmed is not the app's, with the evidence in a comment.
- Check new UI in the Storybook in dark mode, at the largest text size and right to left (Arabic once it is translated, or Direction set to Right to left) before calling it finished.

### Rule 9: Test the logic, the persistence and the promises

- Unit tests use Swift Testing (`@Test`, parameterised with `arguments:`); UI and screenshot tests use XCTest.
- Test pure logic directly (distances, the arrival plan, palette contrast) and persistence through a real in-memory container.
- UI tests launch with `-uiTesting` for an in-memory store and the shipping UI; the screenshot test adds `-screenshotSeed`.
- A UI change that shows up in the App Store screenshots must come with refreshed references, or CI fails.

### Rule 10: Commits tell a story, straight on `main`

- **Work on `main`.** Cards has one contributor, so there are no feature branches and no pull requests: commit to `main` and push. Pushing is the release step, because a push to `main` runs CI and, when CI passes, `deploy.yml` uploads a TestFlight build. Push when the change is ready for testers, and run the loop in section 2 first so CI is a formality.
- **Build numbers are automatic.** The deploy job stamps `CFBundleVersion` from the time on the runner and commits nothing back, so `main` never moves under you.
- One concern per commit, with a conventional prefix: `feat`, `fix`, `refactor`, `style`, `test`, `build`, `ci`, `docs`, `chore`.
- The subject says what changed; the body says why, and anything a reviewer could trip over.
- Each commit builds. Run the loop in section 2 before committing.
- Someone else may be editing the tree: read `git status` and `git diff` before staging, and stage by hunk when a file mixes your change with theirs.
- Write British English in prose, comments and UI copy ("colour"), and Swift's spelling in identifiers (`color`).

## 5. Recipes

### Add a view

1. Write the view in `Cards/UI/Components` or `Cards/UI/Screens`, taking view state and actions ([rule 2](#rule-2-views-are-pure)).
2. Add any sample data it needs to `Cards/Development/SampleData.swift`.
3. Add a story with a knob for every parameter to `ComponentStories.swift` or `ScreenStories.swift`, and list it in that file's story array ([rule 4](#rule-4-every-view-has-a-story-and-every-parameter-has-a-knob)).
4. Add previews, if you want them, in `Cards/Development/Previews/<View>+Previews.swift`.
5. Run the loop, including `make check-release`.

### Add a screen

Do everything in "Add a view", then add a connector in `Cards/Features` that maps models to the view state and wires the actions, a route in `NavigationRoute` if it is navigable, and a case in `CardListScreen.destinationView(for:)`.

### Add a field to a card

1. Add the stored property to `CardItem` with a default, and an init parameter with a default.
2. Add it to `CardItemDTO` as an optional, and map it both ways.
3. Carry it through the view state types that need it, and set it in the connectors.
4. Test: the default, a SwiftData round trip, and an import of an export without the field.
5. Note it for the CloudKit schema deployment before release.

### Add development-only code

Put it under `Cards/Development` and reference it only from other development code. If production code has to reach it (a launch switch, a debug tab), add a hook to `DevelopmentHooks` with the `#if DEBUG` inside the hook, and call the hook. Then run `make check-release`.

### Add a card colour

Add a case to `CardColor` with its display name and a translator comment (`Core/Models/CardColor.swift`) and a swatch in `CardPalette.swift`, run `make test-unit`, and adjust the colour until `CardColorTests` passes.

### Add a package dependency

In Xcode, **File > Add Package Dependencies**, add the product to the `Cards` target, and commit `project.pbxproj` with `Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

### Add or change copy

Every word the app shows or speaks comes from `Cards/Localizable.xcstrings`, or from `Cards/InfoPlist.xcstrings` for the app name and the permission prompts iOS shows. English is the source, and the App Store screenshots pin its wording.

1. **Write it where it is shown.** In a view, `Text("Edit", comment: "…")`. Where an API takes a title, give it a `Text` (`.navigationTitle(Text(…))`, `Button { … } label: { Text(…) }`, `Section { … } header: { Text(…) }`, a text field's `prompt:`), or a `LocalizedStringResource` where it also takes an image (`Label(LocalizedStringResource(…), systemImage:)`). Text that SwiftUI resolves itself follows the `\.locale` it renders in, which is how the Storybook switches language. Core cannot import SwiftUI, so its names are `LocalizedStringResource` (`BarcodeType.displayName`), and a view parameter that carries copy is a `LocalizedStringResource` or `LocalizedStringKey`. Use `String(localized:)` only where it has to be a `String`: notifications, VoiceOver announcements, a name saved into a card.
2. **Comment every string** with where it appears and what it does, and say "a verb" or "a noun" when English could be either. The translator sees only the key and the comment.
3. **Format values in the view**, never as a ready-made string: `Text(date, format: …)`, `Text(radius.metres, format: .radius)`, or interpolated into the key (`"\(distance, format: .distance) from \(place)"`). A count gets English `one` and `other` forms in the catalogue.
4. **User content stays a `String`.** Card names, codes and place names show as typed and are never looked up. Development copy (the Storybook, previews, samples) uses `Text(verbatim:)` or `String` values, or a Debug build would extract it into the catalogue and it would ship.
5. **Codes read left to right.** Card codes, version numbers and JSON take `.readsLeftToRight()`, and a barcode never mirrors. Check the screen right to left in the Storybook.
6. **Fill the catalogue.** `make build` compiles the catalogues but never writes to them, so run `xcodebuild -exportLocalizations -project Cards.xcodeproj -localizationPath /tmp/cards-l10n -exportLanguage en` (with `DEVELOPER_DIR` pointing at Xcode 27.1, as the Makefile sets it). Like a build in Xcode, it adds new keys with their comments, removes unused keys that have no translations, marks unused translated keys `stale`, and fills `InfoPlist.xcstrings` from `Info.plist`. Add any plural forms, then commit the catalogue with the code and translate as below.

### Translate the app, or add a language

The String Catalogues under `Cards/` hold the British English source, and `scripts/l10n.ts` translates them with AI into every language in the project's `knownRegions`. There is no other list of languages.

1. After changing copy, run `make l10n-translate`. It sends only what is missing, empty, flagged for review or broken, validates every reply (placeholders, plural forms) and asks again when one fails. Then `make l10n-check` must pass.
2. To add a language, run `make l10n-add-language CODE=<code>`. It adds the code to `knownRegions` and translates everything into it.
3. The AI works from `l10n/context.md`, the translator brief, plus `l10n/languages/<code>.md` for a language if that file exists. When the app gains a term, add it to the brief's glossary.
4. For a person or another AI to translate or review, run `node scripts/l10n.ts export --lang <code> --out <file>` (add `--force` for every string), fill in the `translation` fields, and run `node scripts/l10n.ts import --lang <code> <file>`.
5. The tool writes catalogues byte for byte as Xcode's catalogue editor does, so Xcode re-saving them changes nothing; `node scripts/l10n.ts normalise` puts a catalogue in that format. `make l10n-test` runs the tool's tests.

### Check the translations on screen

`make capture-l10n` runs `CardsLocalisationScreenshotTests` once per language and text size and writes `/tmp/cards-l10n-qa/<language>/<size>/<screen>.png`: the list, a card's menu, the empty list, a card (and one whose barcode fails), Add Card, Edit Card, the location prompt and map, a place in the form, Settings, the delete-all confirmation and the import sheet. A screen that scrolls is captured a page at a time to its end (`06-add.png`, `06-add-2.png`, …). It visits the screens through the accessibility audit's helpers (`CardsUITests/UITestNavigation.swift`), so a screen added to one belongs in the other. Narrow it with `LANGS="ar ja"` and `SIZES="large AX5"` (`xs` to `xxxl`, `AX1` to `AX5`); `SIMULATOR_DEVICE="iPad Pro 13-inch (M4)" L10N_QA_OUT=/tmp/cards-l10n-qa/ipad` captures on an iPad. Each language runs in its own region (`en` in GB, `ar` in SA, `zh-Hant` in TW), as `-testLanguage` and `-testRegion` would set it. The script keeps its own simulator of that device (`iPhone 16 Pro (Cards l10n QA)`) and sets its system language too, restarting it once per language, because iOS draws the location prompt, with the app's reason for asking, in the system's language rather than the app's. Outside the script the test skips itself, so `make test` never runs it.

Look at every picture for cut-off or overlapping text, controls pushed off screen, English left untranslated, raw keys or `%@`, mirroring right to left (codes and barcodes must not mirror), number and distance formats, and line breaks in Chinese and Japanese. Fix layout in the views; send wording that is wrong or too long back through the tool (`export` and `import`), never by shortening the English.

### Change the app icon

Edit `DesignAssets/Icon.svg`, run `scripts/generate-app-icons.sh`, and commit the SVG with the regenerated PNGs.

### Refresh the App Store screenshots

Run `make capture-screenshots` (about ten minutes for the four device and locale sets), look at every changed PNG under `screenshots/`, and commit them in their own `test:` commit.

## 6. Running and driving the simulator

Xcode 27 has no Simulator.app; `make sim` opens Device Hub to show the screen, and every `simctl` command works headless.

- **Launch arguments:** `-uiTesting` gives an in-memory store and hides the Storybook tab; `-screenshotSeed` adds the six screenshot cards; `-initializeCloudKitSchema` creates the CloudKit schema in the Development environment ([section 8](#8-releasing)). The environment variables `CARDS_UI_TESTING=1` and `CARDS_SCREENSHOT_SEED=1` do the same as the first two. All of them are ignored in release builds.
- **Deep links:** `cards://cards/card/<code>`, `cards://cards/card/<code>/edit` and `cards://cards/new`. `xcrun simctl openurl` shows a confirmation prompt first.
- **Location:** `xcrun simctl privacy <udid> grant location net.serby.Cards`, then `xcrun simctl location <udid> set 51.5203,-0.2094`.
- **Arrival notifications:** give a card a location, send the app to the background, set the simulated location away and then back inside the circle; SpringBoard logs `Location trigger fired` when it delivers.
- **Reinstalling:** uninstall before installing. `simctl install` over a running copy can keep the old binary, and you end up debugging a build you are not running.
- **On an iPhone:** build with `xcodebuild … -destination 'id=<udid>' -allowProvisioningUpdates build`, install with `xcrun devicectl device install app --device <udid> <path to Cards.app>`, and run with `DEVICECTL_CHILD_OS_ACTIVITY_DT_MODE=enable xcrun devicectl device process launch --console --terminate-existing --device <udid> net.serby.Cards`. `OS_ACTIVITY_DT_MODE` copies the app's system log into the console, as Xcode does. Put app arguments after `--` (`… net.serby.Cards -- -initializeCloudKitSchema`), or devicectl reads them as its own options. The phone must be unlocked.

## 7. Signing, teams and iCloud

- The app ID `net.serby.Cards` and the iCloud container `iCloud.net.serby.Cards` belong to the paid Apple Developer team **"Paul Serby" (`ZMBFPG86J4`)**. Both build configurations of the app target must use that team, and so must anyone building to a device.
- A **Personal Team cannot build this app**. Free teams do not support the iCloud capability, and the app ID belongs to another team, so Xcode fails with "Personal development teams … do not support the iCloud capability" and "doesn't include the iCloud capability".
- Every Apple ID comes with a free Personal Team, so "Paul Serby (Personal Team)" in the team menu is not the paid team; it belongs to whichever Apple ID is signed in, which may be a work one. If the menu has no plain "Paul Serby", the Apple ID that owns the paid team is not signed in to Xcode.
- To build to a device, sign in to Xcode (**Settings > Accounts**) with the Apple ID that is a member of `ZMBFPG86J4`, select that team in **Signing & Capabilities** for both configurations, and let Xcode register the device and create the development profile.
- Never sign this app with a company team you happen to belong to.
- Debug builds use `Cards/Cards.Debug.entitlements`, which points at the **Development** CloudKit environment, and Release builds use `Cards/Cards.entitlements`, which points at **Production**. A debug build on your own iPhone therefore syncs a separate set of cards from the App Store app, and can never damage the live data.
- CloudKit change pushes are not enabled yet: the app has neither the `remote-notification` background mode nor the Push Notifications capability, so other devices' changes arrive when the app is opened rather than straight away (CloudKit logs "BUG IN CLIENT OF CLOUDKIT: … require the 'remote-notification' background mode"). Enabling it changes the App ID, which means regenerating the App Store provisioning profile and the `BUILD_PROVISION_PROFILE_BASE64` secret CI signs with.
- `scripts/build-ipa.sh` passes `DEVELOPMENT_TEAM` (default `ZMBFPG86J4`) itself, so archives do not depend on the project's team setting.

## 8. Releasing

1. Push to `main` (rule 10). CI runs lint, the build, the release check, the tests and the screenshot comparison, and when it is green `deploy.yml` uploads to TestFlight.
2. If the build adds stored fields, deploy the CloudKit schema first; Production rejects records whose type or fields it does not have, with "Cannot create new type … in production schema" or "Cannot create or modify field …". Launch a Debug build once with `-initializeCloudKitSchema`, on a device or simulator signed in to iCloud, and wait for the log line "CloudKit schema initialised in the Development environment". Then open the [CloudKit Console](https://icloud.developer.apple.com/dashboard/), choose `iCloud.net.serby.Cards`, and use **Deploy Schema Changes** to copy the Development schema to Production.
3. `make deploy-testflight` or `make deploy-appstore` archive with `scripts/build-ipa.sh` and upload with an App Store Connect API key (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`). In CI, `deploy.yml` uploads to TestFlight after CI passes on `main`, and `release.yml` submits to the App Store on `v*` tags.
4. `scripts/upload-metadata.sh` and `scripts/upload-screenshots.sh` push the store listing from `metadata/` and `screenshots/`.

`.github/workflows/ci.yml`, `deploy.yml` and `release.yml` are the source of truth for the pipelines; `docs/CICD_SETUP.md` and `docs/DEPLOYMENT.md` cover the one-off account and secrets setup.

## 9. Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| "Personal development teams … do not support the iCloud capability" | The project's team is a Personal Team. Use `ZMBFPG86J4` ([section 7](#7-signing-teams-and-icloud)) |
| "Device … isn't registered in your developer account" | Building to a device or "My Mac (Designed for iPad)" with a team that has not registered it. Select `ZMBFPG86J4`; Xcode offers to register it |
| Release build fails with "has no member 'sample'" or similar | Production code, often a preview left beside a view, names something in `Cards/Development`. Move the preview or go through `DevelopmentHooks` |
| `make check-release` lists a declaration | That development type or member is reachable from production code. Find the reference and route it through a hook |
| The app behaves like an older build | `simctl install` kept the old binary; uninstall, then install |
| A build fails in `PrecompileModule` with "cannot find interface declaration" | Stale generated `*-Swift.h` headers after a type was deleted; delete them under `fastlane/derived_data/Build/Intermediates.noindex` and rebuild |
| "Cannot create new type CD_CardItem in production schema" in the log | The Production CloudKit schema is missing the model; deploy it ([section 8](#8-releasing)) |
| The map picker freezes the app | Something updates `Map` content from `onMapCameraChange` ([rule 7](#rule-7-swift-6-no-warnings-clean-lint)) |
| A story shows several Edit buttons | The screen story is missing `galleryLayout: .oneAtATime` |
| The Storybook's Language menu lists a language that has no translations | When a language's last translation goes, Xcode leaves its empty `.lproj` folder in the built app and the bundle still lists it. Delete the folder from `Cards.app` in `BUILT_PRODUCTS_DIR`, or clean the build folder in Xcode |
| New copy is missing from `Localizable.xcstrings` | Command-line builds never write to catalogues; run `xcodebuild -exportLocalizations` ([Add or change copy](#add-or-change-copy)) |
| Storybook or preview text turns up in `Localizable.xcstrings` | A literal reached a `LocalizedStringKey` in `Cards/Development`; make it `Text(verbatim:)` or a `String` |
| An English device shows a translation | `Info.plist` must keep `CFBundleDevelopmentRegion`: catalogues compile no `en.lproj` for unchanged English, so without it iOS picks one of the translations |
