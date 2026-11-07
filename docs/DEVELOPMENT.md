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
| Xcode 27.1 | Builds, tests, simulators | The version is pinned in `.xcode-version`, and local builds and CI must use it. `scripts/lib/xcode.ts`, which every script and the Makefile (through `scripts/select-xcode.ts`) use, takes `XCODE_APP` if set, else `/Applications/Xcode<version>.app` (or `Xcode_<version>.app`, as on GitHub's runners), and stop with an error if that Xcode is missing or is another version. CI runs on GitHub's `xcode-27` image. To move to a new Xcode, change `.xcode-version`, and the `runs-on` image in `ci.yml` and `release.yml` if the major version changes, in one commit |
| SwiftLint | Lint, run before every build | `.swiftlint.yml` at the root |
| Node 24 | Every script in `scripts/` ([rule 14](#rule-14-scripts-are-typescript-named-for-what-they-do)) | Runs TypeScript directly, no install step |
| Claude Code | `make l10n-translate` | The default AI for translations; any other command can stand in through `L10N_AI_COMMAND` |
| librsvg, ImageMagick | App icon rendering only | `brew install librsvg imagemagick` |

Open the project with `open Cards.xcodeproj`. There is no generator step: the project is checked in, and the app target reads every file under `Cards/` through a file system synchronised group, so a new file or folder on disk is in the build with nothing to add.

The deployment target is iOS 18.0. The app is built with the iOS 27 SDK, so anything newer than iOS 18 must sit behind `if #available` (see `tabBarMinimizeBehaviorIfAvailable()` for the pattern).

## 2. The everyday loop

### Shape features in the simulator before they ship

Anything Paul needs to see and shape, such as a new screen, a new flow or a change to how something looks, is reviewed in the simulator before it goes anywhere:

1. Build it, run the loop below, and run it in the simulator (`make sim`; launch with `-uiTesting -screenshotSeed` for the seeded cards and a fixed location).
2. Show it: say what changed and share simulator screenshots of each affected screen, in light and dark mode where it matters.
3. Iterate on the feedback. Commit as you go, but do not push: `main` is what the next version ships from, and the change is not ready until Paul says so.
4. Once Paul agrees it ships as a new version of the app, refresh the screenshots (`make capture-screenshots`, then `make store-screenshots`), commit them, run the loop again and push. Update the App Store listing when that version is being prepared for release ([Update the App Store listing](#update-the-app-store-listing)).

Fixes, tooling and documentation that change nothing on screen do not need this and can be pushed when the loop passes.

### The loop

Run these in order after every change, and fix what fails before moving on:

1. `swiftlint lint`
2. `make build`
3. `make test`, or `make test-unit` while iterating on logic
4. `make check-release` whenever you add or move code in `Cards/Development`, touch `Cards/App/DevelopmentHooks.swift`, or add a preview
5. `node scripts/l10n.ts check` whenever copy or a catalogue changes ([rule 17](#rule-17-every-string-is-translatable-and-translated))
6. `make capture-screenshots` and `make store-screenshots` when a change to what the screenshots show is agreed to ship (above), then look at every changed PNG before committing it

| Command | What it does |
|---------|-------------|
| `make build` | Build the app (Debug) for the simulator |
| `make test` | Unit and UI tests |
| `make test-unit` | `CardsTests` only |
| `make test-e2e` | `CardsUITests` only |
| `make test-a11y` | The accessibility audit on every screen, in English, and right to left at the largest text size |
| `make test-tsan` | Unit tests under the thread sanitiser |
| `make test-coverage` | Tests on iPhone and iPad plus an HTML coverage report in `coverage-html/` |
| `make coverage-report` | The report from the last coverage run, without testing again |
| `make check` | The quick checks: metadata, changelog, raw screenshots and store images |
| `make check-release` | Build Release and fail if any development code reached it ([rule 1](#rule-1-development-code-never-ships)) |
| `make sim` | Build, boot the simulator, show it in Device Hub, install and launch |
| `make device` | Build and install on a connected iPhone |
| `make capture-screenshots` | Capture the raw screenshots on iPhone, iPad and iPhone Duo in every store locale (the folders in `metadata/`) |
| `make store-screenshots` | Compose the App Store images and the creative asset from the raw screenshots, their captions and `creative-asset.json` |
| `make check-screenshots` | Check the raw captures and that every store image is present |
| `make upload-build` | Archive, export and upload a build to App Store Connect |
| `make l10n-status`, `make l10n-check` | Translation counts per catalogue and language; fail if any language is incomplete or broken (`node scripts/l10n.ts status`, `check`) |
| `make l10n-translate` | Translate what needs it with AI (`LANGS="de ja"` for some languages only) ([recipe](#add-or-change-copy)) |
| `make l10n-add-language CODE=<code>` | Add a language and translate everything into it ([recipe](#add-a-language)) |
| `make test-scripts` | The scripts' own tests (`node --test scripts/*.test.ts`) |
| `make capture-l10n` | Screenshot every screen in every language at the default and largest text sizes, for checking translations by eye ([recipe](#check-every-language)) |

Override `SIMULATOR_DEVICE` and `SIMULATOR_VERSION` on the command line to target another simulator.

Xcode on this project writes build products to `fastlane/derived_data/Build/Products` (a custom build location preference), not to `-derivedDataPath`. Never guess the path; ask: `xcodebuild -project Cards.xcodeproj -scheme Cards -showBuildSettings | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p'`.

## 3. Project layout

One app target and one widget extension. The app is a single Swift module whose folders are layers by convention, so the compiler will not stop a violation; the rules in section 4 do.

```
Cards/
  App/           Entry point, and DevelopmentHooks: the only door into Development
  Core/          Models, navigation and services. No SwiftUI views
    Models/        CardItem (SwiftData), CardItemDTO, BarcodeType, CardColor, CardLocation, WidgetCard, ArrivalAlert,
                   DistanceUnits and DistanceFormat (how distances and radii are written)
    Navigation/    NavigationRoute, NavigationManager, SharedCardLink, deep links
    Services/      CardStore, LocationService, PerformanceTracker, and the clients (rule 15):
                   NotificationClient, PlaceSearch, Clipboard, WidgetSnapshot, WidgetSettings, FileReader
  UI/            Every view, as a pure function of view state and actions
    Screens/       CardListView, CardDetailView, CardEditView, LocationPickerView, SharedCardView, SettingsListView
    Components/    BarcodeView, BarcodeImage, CardColorPicker, CardLocationRow, CardWidgetView, ProximityLabel, …
    ViewState/     CardSummary, CardDetail, CardDraft, CardWidgetState, SettingsState
    Actions/       Closure bundles each screen raises
    Environment/   Injected effects: ScreenBrightness, AccessibilityAnnouncer; and the distance units
    Theme/         Colours, the card palette
  Scanner/       Camera scanning (AVFoundation), pinch to zoom
  Features/      Connectors: SwiftData, navigation, location and clients in, view state out;
                 the arrival notifications (ArrivalPlan, ArrivalScheduler, ArrivalNotificationRouter)
  Development/   Never in a release build. The Development tab's tools (Tools/), Storybook, previews,
                 sample data, stand-ins, test seeds
CardsWidget/     The Home Screen widget extension: timeline, configuration intents, WidgetLocation
CardsTests/      Unit tests (Swift Testing)
CardsUITests/    UI and screenshot tests (XCTest)
```

The widget cannot open the SwiftData store, so the list screen writes every card to a JSON file in the App Group container (`WidgetSnapshot`) and the widget reads that. Settings the widget follows, such as the distance units, are copied the same way by `CardsApp` (`WidgetSettings`). The widget compiles a short list of files from `Cards/` (models, `BarcodeImage`, `CardWidgetView`, the palette); the list is the "Exceptions for \"Cards\" folder in \"CardsWidget\" target" set in the project, which is what Xcode's Target Membership box edits. A shared file may only use what is on that list, so keep it to Foundation, SwiftUI and other shared files.

Dependencies point one way:

```
App ──▶ Features ──▶ UI ──▶ Core
              └────▶ Core
Development ──▶ anything          (nothing in production ──▶ Development, except DevelopmentHooks)
```

## 4. Rules

### Rule 1: Development code never ships

Development code is anything that exists to build, preview, test or demonstrate the app rather than to run it: the Storybook, `#Preview` blocks, sample data and fixtures, simulated effects and stand-in clients (`ScreenBrightness.simulated`, `AccessibilityAnnouncer.silent`, `NotificationClient.silent`), stand-in views (`ScannerPlaceholderView`), UI-test switches and screenshot seed data, and debugging aids (`Loader`). None of it may reach a release build, and none of it may clutter production code with `#if DEBUG`.

1. **It lives in `Cards/Development/`.** The Release configuration of the `Cards` target excludes that folder (`EXCLUDED_SOURCE_FILE_NAMES`), so files there are plain Swift with no `#if DEBUG` of their own. The patterns cover three folder levels below `Cards/Development`; add a pattern in the project if you ever need a fourth.
2. **Previews are the one exception: they sit at the bottom of the view's own file, inside `#if DEBUG`,** so Xcode's canvas shows them when the view is open. Release builds type-check `#Preview` bodies even though they strip them, so without the `#if DEBUG` a preview would drag sample data into the release compile. One `#if DEBUG … #endif` wraps all of a file's previews and nothing else. A view built into the widget extension too (`CardWidgetView`) cannot reach `Cards/Development`, so its previews carry their own data.
3. **Production code reaches development code only through `Cards/App/DevelopmentHooks.swift`.** Each hook is one function or property whose body holds the `#if DEBUG` and returns something inert in release (`false`, nothing, an empty view). Call sites never contain `#if DEBUG`.
4. **`#if DEBUG` appears nowhere else.** `grep -rn "#if DEBUG" Cards` lists `DevelopmentHooks.swift` and the files whose previews it wraps, and nothing else; around anything other than previews it is a mistake.
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
- **Injected effects** (`UI/Environment`): environment values whose default is the real thing (`.live`). Stories and previews swap in the substitutes from `Cards/Development/SimulatedEffects.swift`, so a story can never change the device's brightness or speak with VoiceOver.
- **View slots** for anything device-bound: `CardEditView` is generic over its scanner, so the app passes the camera and stories pass `ScannerPlaceholderView`.

If a view needs a new capability, add an action or an injected effect; never reach for a singleton or `@Environment(\.modelContext)` inside `Cards/UI`.

### Rule 3: Impure work lives in connectors and services

`Cards/Features` holds one connector per screen (`CardListScreen`, `CardDetailScreen`, `CardEditScreen`, `SettingsScreen`, and `SharedCardScreen` for the "Add Card?" sheet, which `CardsApp` presents). A connector reads `@Query`, `modelContext`, `NavigationManager`, `LocationService` and the clients it needs from the environment ([rule 15](#rule-15-small-parts-injected-dependencies-no-global-state)), maps models to view state, and wires actions back to effects. Long-lived device services (`LocationService`) and clients live in `Core/Services`; the services are injected with `.environment` from `CardsApp`. Integration glue that also needs UI code (`ArrivalPlan` and `ArrivalScheduler`, which render barcodes, and `CardShareImage`, which draws the shared picture) lives in `Features`.

Keep the logic of a service testable without the device: `ArrivalPlan` is pure, and `ArrivalScheduler` is tested through a stand-in `NotificationClient` rather than `UNUserNotificationCenter`.

### Rule 4: Every view has a story and a preview, and every parameter has a knob

Every view in `Cards/UI` has a story in `Cards/Development/Storybook/Catalogue`, and every parameter of that view has a knob. Use the knob kinds in `Story.swift` (toggle, text, number, options) and give the story a gallery of the fixed variants worth eyeballing.

- Screens set `galleryLayout: .oneAtATime`. SwiftUI puts every visible screen's toolbar items in the Storybook's one navigation bar, so a list of screens would show one Edit button per variant.
- Reuse the shared knobs rather than inventing new names: `ProximityKnobs` for anything that shows a distance, and `DistanceKnobs`, applied with `.distances(knobs)`, for anything that writes a distance or a radius. `ProximityKnobs` includes `DistanceKnobs`.
- Bindings to local state go through `Stateful`; bindings to knobs through `KnobValues.*Binding`.
- A value read once at creation (a map's starting camera) needs `.id(knobValue)` so the story rebuilds when the knob changes.
- Each story's toolbar has a display options menu: appearance, text size, language and direction, applied to whichever story is on screen in either mode. Language offers System and every localisation compiled into the app, so a language appears as soon as it has a translation; what it can and cannot switch is in [rule 17](#rule-17-every-string-is-translatable-and-translated). Direction is Automatic (the language's script direction), Left to right or Right to left. The language and direction persist between launches in their own defaults suite, `net.serby.Cards.Storybook`, which the app never reads.

Every main view, each screen, connector and reusable component, also has an Xcode preview, for the canvas while you work on it. Stories explore every parameter; previews show only the few states worth seeing at a glance.

- **Where:** at the bottom of the view's own file, in one `#if DEBUG … #endif` block, so the canvas shows them as you edit the view and they never ship (rule 1).
- **What:** one to three named `#Preview`s of the states that matter, such as "Barcode" and "QR code", or "New card", "Already here" and "Unreadable link". Build them from `SampleData.swift`, and use `@Previewable @State` for bindings.
- **Effects:** give previews the same stand-ins as stories (`.simulated`, `.silent`), and give connectors an in-memory model container and any environment objects they need.
- **Not needed** for private subviews and small pieces of one view, such as a row inside a list, or for the live camera scanner.

### Rule 5: Follow the visual style guide

[docs/STYLE.md](STYLE.md) is the style guide: corners nest (an inset shape takes the outer radius minus the inset, with the radii in `UI/Theme/CardGeometry.swift`), text on a card colour is readable by construction (a white panel, or the colour's ink over its readable gradient), colours come from the palette or the custom picker, and card faces use the colour's gradient. `CardColorTests` checks WCAG AA (4.5:1) for every palette colour's ink, for text on the gradient of any colour, and for the accent; `CardGeometryTests` checks the radii nest. If a test fails, change the colour, never the threshold.

- Draw supporting text in `Color.secondaryText`, not the system's `.secondary`, `secondaryLabel` or `tertiaryLabel`, which measure 1.7 to 3.4:1 on white. New text on a new surface gets a line in `secondaryTextIsReadableOnEverySurface`.

### Rule 6: Models stay CloudKit- and export-compatible

The SwiftData store syncs through CloudKit, and users keep JSON exports. So:

- Every `@Model` property has a default value; no unique constraints; relationships optional.
- Enums are stored by raw value with a tolerant reader (`CardColor.stored(_:)`, `CardItem.getBarcodeType()`), so an unknown value from a newer build falls back instead of failing.
- New `CardItemDTO` fields are optional, and a test decodes an export from before the field existed.
- Persisting a new kind of value gets a round-trip test through a real in-memory `ModelContainer` (`cloudKitDatabase: .none`).
- Before a build with new fields ships, the CloudKit schema must be deployed to Production (see [section 8](#8-releasing)).
- The store stays in the app's own container. SwiftData puts its default store in the first App Group in the entitlements, and the widget added one, so `CardStore.configuration` passes `groupContainer: .none`; without it every existing card would be stranded in the old file. `CardStoreTests` checks the path. Always build the container through `CardStore`.

### Rule 7: Swift 6, no warnings, clean lint

The target builds in Swift 6 language mode with strict concurrency, `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `ExistentialAny`. Patterns that keep it clean:

- UI-facing services are `@MainActor`; delegate callbacks from Apple frameworks are `nonisolated` and hop back with `MainActor.assumeIsolated` when the framework calls on the main thread.
- Keep non-`Sendable` framework values inside the function that made them; return your own `Sendable` struct (`PlaceMatch`) instead.
- With several closures, use labelled closure arguments, not trailing closure syntax.
- Silence a lint rule only on the line that needs it, with `// swiftlint:disable:next rule_name` and a comment saying why.
- Never update `Map` content from `onMapCameraChange`: MapKit re-applies the camera and loops. Draw camera-relative overlays in screen space, as `LocationPickerView` does with its pin and radius ring (`MapPinRing`).

### Rule 8: Accessibility is part of done

- Every control a UI test touches has an `accessibilityIdentifier`; every meaningful control has a label in plain words.
- Never put an identifier on a `Section` or a `Form`: it replaces the identifier of every control inside.
- When something changes without a new screen (a scan, a search, a delete), say so through the injected `accessibilityAnnouncer`, with the message in `Announcements` if a view shares it. Never announce on appearing, which cuts across VoiceOver reading the screen; move focus with `@AccessibilityFocusState` instead, as the card screen does to its name.
- Nothing needs a gesture: whatever a swipe, drag or pinch does is also a context menu item or a named accessibility action (`accessibilityActions`), as the card list's Move Up, Move Down and Delete are. Controls never hide while assistive technology may need them.
- UI tests find elements by identifier, or tabs by position, rather than by their text, so they pass in any language; a test that reads English copy runs in English. `CardsRightToLeftUITests` runs `CardsUITests` again right to left and checks that it is. No right-to-left language ships yet (Arabic is held back, `l10n/context.md`), so it forces the direction in English with `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`, as a right-to-left translation would set it; once Arabic ships, it can run in Arabic with no forcing arguments.
- Decorative images are hidden from VoiceOver; codes are read character by character (`speechSpellsOutCharacters()`).
- Barcodes, card faces and colour swatches take `.keepsColoursWhenInverted()`, so Smart Invert leaves a barcode scannable and a red card red. `SmartInvertTests` checks they keep it.
- Layouts survive the accessibility text sizes: switch from side by side to stacked with `AnyLayout` when `dynamicTypeSize.isAccessibilitySize`, with no `Spacer` inside the `AnyLayout` (it does not know its axis there). A screen whose content can outgrow the display scrolls; text fields take `axis: .vertical` with a `.singleLine()` binding so long text wraps, and an empty prompt of their own with `.wrappingPrompt(…)` showing the real one, as a field's own prompt never wraps and was cut off; a symbol's column or a swatch grows with `@ScaledMetric`.
- The Home Screen widget is a fixed size, so `CardWidgetView` lets its text grow to xxLarge (`largestTextSize`) and no further, which keeps room for a barcode that scans; the card's own screen shows everything at every size. Its barcode and background keep their colours under Smart Invert, its code reads left to right, and its refresh button is an element of its own.
- Every tappable thing is at least 44 by 44 pt, including what VoiceOver alone acts on, such as the map pin.
- Speech gets words, not abbreviations: format a distance or radius in an accessibility label with the environment's `distanceFormat` and `width: .wide` ("350 metres"), and a value shown as "350 m" with its default width.
- Large movements honour `accessibilityReduceMotion`: animate them with `nil` when it is on.
- With Increase Contrast (`colorSchemeContrast == .increased`) secondary ink becomes primary, rows, cards and cells get an edge, and the app's own colours take their stronger variant (`Color(lightRGB:darkRGB:increasedLightRGB:increasedDarkRGB:)`).
- Main actions have keyboard shortcuts: ⌘N adds a card, ⌘E edits, ⌘S saves, ⌘Return confirms a sheet and Escape cancels it; Return moves to the next field.
- `CardsAccessibilityAuditTests` runs Xcode's accessibility audit (`performAccessibilityAudit`) on every screen, and `CardsRightToLeftLargeTextAuditTests` again right to left at the largest text size (`make test-a11y`, or part of `make test`). A new screen gets a test in both. Fix what it finds; add to `isKnownFalsePositive` only an issue you have confirmed is not the app's, with the evidence in a comment.
- Check new UI in the Storybook in dark mode, at the largest text size and right to left (Direction set to Right to left) before calling it finished.

### Rule 9: Test the logic, the persistence and the promises

- Unit tests use Swift Testing (`@Test`, parameterised with `arguments:`); UI and screenshot tests use XCTest.
- Test pure logic directly (distances, the arrival plan, palette contrast), stateful services through stand-in clients (`ArrivalSchedulerTests`), and persistence through a real in-memory container.
- UI tests launch with `-uiTesting` for an in-memory store and the shipping UI; the screenshot test adds `-screenshotSeed`.
- A UI change that shows up in the App Store screenshots must be pushed with refreshed references, or CI fails. Refresh them when the change is agreed to ship, not while it is still being shaped ([section 2](#shape-features-in-the-simulator-before-they-ship)).

### Rule 10: Commits tell a story, straight on `main`

- **Work on `main`.** Cards has one contributor, so there are no feature branches and no pull requests: commit to `main` and push. A push to `main` runs CI; nothing is uploaded until a version is tagged ([section 8](#8-releasing)). Push when the change is ready to ship, and run the loop in section 2 first so CI is a formality. A feature Paul needs to see is ready only once he has agreed it ships ([section 2](#shape-features-in-the-simulator-before-they-ship)).
- **Build numbers are automatic.** The release job passes a build number from the time on the runner to `scripts/build-ipa.ts` as `BUILD_NUMBER`, which sets `CURRENT_PROJECT_VERSION` for the app and widget together, and commits nothing back, so `main` never moves under you.
- One concern per commit, with a conventional prefix: `feat`, `fix`, `refactor`, `style`, `test`, `build`, `ci`, `docs`, `chore`.
- The subject says what changed; the body says why, and anything a reviewer could trip over.
- Each commit builds. Run the loop in section 2 before committing.
- Someone else may be editing the tree: read `git status` and `git diff` before staging, and stage by hunk when a file mixes your change with theirs.
- Write British English in prose, comments and UI copy ("colour"), and Swift's spelling in identifiers (`color`).


### Rule 11: Features are agreed in the simulator before they ship

A change Paul needs to see is built, tested and run in the simulator, and shown to him with screenshots, before it is pushed. It is pushed, with its screenshots refreshed in the same push, only once he agrees it ships as a new version of the app. Fixes, tooling and documentation that change nothing on screen are exempt. The steps are in [section 2](#shape-features-in-the-simulator-before-they-ship), and the simulator review skill ([.claude/skills/simulator-review/SKILL.md](../.claude/skills/simulator-review/SKILL.md)) runs them.

### Rule 12: Mark changes with the release skill

`changelog.json` is the one record of what changed for the people using the app, newest version first. `node scripts/generate-changelog.ts` writes `CHANGELOG.md` and each locale's `metadata/<locale>/release_notes.txt` from it, the app bundles it for Settings > What's New, and CI's `node scripts/check-changelog.ts` fails when a generated file is stale or the newest version is not the app's. Each entry of the version in preparation carries its text in every app language beside its British English (`"es"`, `"de"`, `"ja"`, and `"en-US"` or `"es-MX"` where a listing's wording differs), and check-changelog fails while one is missing; the app shows each entry in its own language, and older versions in English. The release skill ([.claude/skills/release/SKILL.md](../.claude/skills/release/SKILL.md)) is the standard way to add entries, from the commits, and to release a version. Never edit `CHANGELOG.md` or `release_notes.txt` by hand.

### Rule 13: Keep the spec current

[spec/](../spec/README.md) describes the whole app as user stories with acceptance criteria. A change that adds or alters behaviour updates the matching stories in the same commit, and a new feature adds new ones, marked "In preparation for <version>" until it ships.

### Rule 14: Scripts are TypeScript, named for what they do

All code in the project is Swift or TypeScript. The app, the widget and the tests are Swift; every script and helper is TypeScript in `scripts/`. There is no Python, Ruby, JavaScript or shell script, and no shell, Python or Node logic embedded in another file.

- **Run them with Node 24:** `node scripts/<name>.ts`. Node strips the types itself, so there is no build step and no npm install. That means no enums, no namespaces and no constructor parameter properties; use `import type` for types and give import paths their `.ts` extension. Use only Node's built-in modules.
- **Name a script with a verb** that says what it does: `check-metadata.ts`, `capture-screenshots.ts`, `submit-for-review.ts`. A script does one job; if it needs subcommands, split it.
- **Share code through `scripts/lib/`,** whose modules are named for what they provide (`app-store-connect.ts`, `xcode.ts`, `simulator.ts`, `changelog.ts`) and are never run directly.
- **Run Xcode's tools through `scripts/lib/xcode.ts`,** so every script uses the Xcode in `.xcode-version`.
- **Start every script with a comment** saying what it does and a `// Usage:` line.
- **Keep the Makefile and the workflows thin.** A Makefile recipe or a workflow step only runs tools and scripts in order. Any logic, loop, condition or parsing, beyond a GitHub expression, belongs in a script.
- **Delete what nothing uses.** A script with no caller in the Makefile, a workflow, another script or this guide is removed, not kept in case.

### Rule 15: Small parts, injected dependencies, no global state

The app's Swift follows a few long-standing design principles, applied where they pay rather than for their own sake.

- **No global mutable state.** No `static var` that stores state, no singletons of our own and no mutable top-level variables. State belongs to an instance someone owns: an `@Observable` model created once at the composition root and passed down (`LocationService`, `NavigationManager`, `ArrivalScheduler`), a view's `@State`, or SwiftData. Immutable `static let` constants and loggers are fine. `DevelopmentHooks` is the one deliberate exception, because rule 1 needs it to be static.
- **Inject every dependency with a side effect.** Anything that reaches the system or the outside world, such as notifications, location, geocoding, the clipboard, opening URLs, the widget's App Group file, screen brightness or VoiceOver, is a dependency:
  - **Model it** as a small `Sendable` struct of closures, a client, with a `.live` value. The `.live` value, or the factory it is built from (such as `WidgetSnapshot.file(at:)`, which tests point at a temporary file), is the only place the system API is called.
  - **Provide it** through SwiftUI's environment, with `.live` as the default, and read it with `@Environment` in connectors and effects. `ScreenBrightness` and `AccessibilityAnnouncer` in `UI/Environment` are the pattern, and `PlaceSearch`, `Clipboard`, `WidgetSnapshot` and `WidgetSettings` in `Core/Services` follow it.
  - **Prefer SwiftUI's own environment actions** where they exist, such as `openURL`.
  - **Outside views,** such as the widget's timeline provider (`WidgetSnapshot`, `WidgetLocation`) and `ArrivalScheduler` (`NotificationClient`), take clients in `init`, defaulting to `.live`.
  - **Keep clients small.** A client exposes only the operations its callers use (interface segregation).
- **Stateful services are owned instances.** A service that has to remember something, such as `ArrivalScheduler`, `LocationService` and `NavigationManager`, is an `@Observable` class created once at the composition root, injected with `.environment(_:)`, and given its clients in `init`. It has no environment default, because a default would be a hidden shared instance; a screen without it fails at once rather than quietly using a second one.
- **Wire everything at the composition root.** `CardsApp`, and the widget's entry point, create the long-lived models and live clients once, and hand iOS the delegates it calls, such as the arrival notification router. Nothing else calls a system singleton (`.shared`, `.current()`, `.standard`, `.default`, `.general`) except a client's `.live` value, and the camera scanner, which is itself the live camera component that stories replace with a placeholder.
- **Case-less enums are for pure code only:** constants and stateless functions with no side effects, such as `CardGeometry`, `WCAG`, `CardImport` and `ArrivalPlan`. A case-less enum that touches the system is a dependency in disguise, so make it a client.
- **One reason to change (single responsibility).** Views render, connectors connect a screen to its data, and services and clients each do one job. A file holds one main type, plus small types that only serve it (a view's private subviews, a model's DTO). Depend on the injected client, not on the concrete system API (dependency inversion). Add a protocol only at a dependency boundary that has, or will soon have, more than one implementation.
- **Keep it simple (KISS, YAGNI).** Write the simplest code that meets today's need. Add generics, configuration or layers when a second real use arrives, not before.
- **Don't repeat knowledge (DRY).** Every fact lives in one place: a colour, a radius, a rule such as "codes are unique", or a string the app and the store share. Code that only looks alike can stay apart until a third copy appears; then extract it.
- **Test through the seams.** Logic is tested with stand-in clients, never by waiting on real notifications, location or the network.

### Rule 16: Words follow the language guide

[LANGUAGE.md](LANGUAGE.md) covers spelling, voice and capitalisation for everything people read: the app, notifications, the App Store listing, the website and the changelog. Every example, in the store screenshots, placeholders, sample data, previews, stories, tests, the spec and the docs, uses its cast of made-up businesses (Joe's Market, Local Roast Coffee and the rest), never a real brand.

### Rule 17: Every string is translatable and translated

Every word the app shows or speaks comes from `Cards/Localizable.xcstrings`, or from `Cards/InfoPlist.xcstrings` for the app's name and the permission prompts iOS shows. The widget extension is a bundle of its own, so its words come from its own `CardsWidget/Localizable.xcstrings` and `CardsWidget/InfoPlist.xcstrings` (its location prompt). A file compiled into both targets, such as `CardWidgetView` or `ProximityLabel` (the list in [section 3](#3-project-layout)), puts its strings in both catalogues, as each bundle must carry its own copy; the tool treats a string with the same key, English and comment in both as one, translating it once, copying a translation one already has to the other, and failing `check` if they ever differ. British English is the source, and every language in the project's `knownRegions` has all of it: today Spanish, German and Japanese, the first wave; the languages held back for later waves, and how to bring one back, are in `l10n/context.md`. English is also the key, so changing the English makes a new key that needs translating again.

1. **Copy is written in the view, with a comment for the translator.** In a view, `Text("Edit", comment: "…")`. Where an API takes a title, give it a `Text` (`.navigationTitle(Text(…))`, `Button { … } label: { Text(…) }`, `Section { … } header: { Text(…) }`, a text field's `prompt:`), or a `LocalizedStringResource` where it also takes an image (`Label(LocalizedStringResource(…), systemImage:)`). Core cannot import SwiftUI, so its names are `LocalizedStringResource` (`BarcodeType.displayName`), and a view parameter that carries copy is a `LocalizedStringResource` or `LocalizedStringKey`. App Intents titles, descriptions, parameters and display representations take a `LocalizedStringResource("…", comment: "…")`, which the system resolves in the language it shows them in; a widget's gallery name and description take a `Text`. A user's own text in a display representation is `"\(name)"`, whose `%@` key is marked Don't Translate in the catalogue, so a card called "Settings" is never looked up. Use `String(localized:)` only where it has to be a `String`: notifications, VoiceOver announcements, a name saved into a card. The comment says where the string appears, what it does and what fills each placeholder, and "a verb" or "a noun" when English could be either: the translator sees only the key and the comment. Give different jobs different English, as one key has one translation: a deleted card and a deleted place each have their own announcement, so a language can make it agree with either.
2. **Values are formatted in the view**, never passed as a ready-made string: `Text(date, format: …)`, or a distance or radius from the environment's `distanceFormat` (`DistanceFormat`, which takes the units chosen in Settings and the environment's locale) interpolated into the key (`"\(distanceFormat.distance(metres)) from \(place)"`). A count gets English `one` and `other` forms in the catalogue. User content stays a `String`: card names, codes and place names show as typed and are never looked up.
3. **Codes read left to right.** Card codes, version numbers and JSON take `.readsLeftToRight()`, and a barcode never mirrors.
4. **No development copy in the catalogue.** The Storybook, previews and samples use `Text(verbatim:)` or `String` values; a literal in a `LocalizedStringKey` there is extracted into the catalogue by a Debug build, and would ship.
5. **`node scripts/l10n.ts check` passes** (`make l10n-check`, and in CI): every key in every language, with its placeholders and plural forms, and no stale keys.
6. **Adding or changing copy means `exportLocalizations`, then `translate`, then a review** of every new translation against its language's style guide, as [Add or change copy](#add-or-change-copy) describes.

What SwiftUI resolves as it renders follows the `\.locale` it renders in, which is how the Storybook's language option switches it: `Text` and `Label` from a key or a `LocalizedStringResource`, prompts, picker items, the titles, messages and `Text` buttons of alerts and dialogs, sheets, `FormatStyle`s in a `Text` or a key's interpolation, and SwiftUI's own copy (`EditButton`, `DatePicker`). It cannot switch what is resolved before SwiftUI sees it or drawn by UIKit: `String(localized:)` (VoiceOver announcements, notifications), `.formatted()` strings, the OK and Cancel buttons iOS adds to alerts and dialogs, and the keyboard. A sheet takes the language but keeps the app's direction. Check those by running the app in the language: the scheme's App Language, or launch with `-AppleLanguages '(de)'`.

Why: a string that skips the catalogue is English in every language, a string without a comment is a guess, and a translation nobody has read can be wrong in ways no tool catches. The check turns a missing or broken translation into a failed CI run rather than a tester's bug report.

## 5. Recipes

### Add a view

1. Write the view in `Cards/UI/Components` or `Cards/UI/Screens`, taking view state and actions ([rule 2](#rule-2-views-are-pure)).
2. Add any sample data it needs to `Cards/Development/SampleData.swift`.
3. Add a story with a knob for every parameter to `ComponentStories.swift` or `ScreenStories.swift`, and list it in that file's story array ([rule 4](#rule-4-every-view-has-a-story-and-a-preview-and-every-parameter-has-a-knob)).
4. Add its previews at the bottom of the view's file, inside `#if DEBUG` (rule 4).
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

Add a case to `CardColor` with its raw value in `CardColor.swift`, then its hex, and its display name with a comment for the translator, in `CardPalette.swift`, keeping the picker's rows full ([docs/STYLE.md](STYLE.md), section 3). Run `make test-unit` and adjust the colour until `CardColorTests` passes.

### Add a package dependency

In Xcode, **File > Add Package Dependencies**, add the product to the `Cards` target, and commit `project.pbxproj` with `Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

### Add or change copy

1. **Write it** as [rule 17](#rule-17-every-string-is-translatable-and-translated) says: in the view, with a comment for the translator. The App Store screenshots pin the English wording of the list, a card's screen, the edit form and the location picker, so changing it there means [refreshing them](#refresh-the-app-store-screenshots).
2. **Fill the catalogue.** `make build` compiles the catalogues but never writes to them, so run `xcodebuild -exportLocalizations -project Cards.xcodeproj -localizationPath /tmp/cards-l10n -exportLanguage en` (with `DEVELOPER_DIR` pointing at Xcode 27.1, as the Makefile sets it), then `node scripts/l10n.ts normalise`. Like a build in Xcode, the export adds new keys with their comments, removes unused keys that have no translations, marks unused translated keys `stale`, and fills each target's `InfoPlist.xcstrings` from its `Info.plist` and `INFOPLIST_KEY_` settings. An Info.plist string has no line of code to carry its comment, so write one in the catalogue, where the export keeps it, and mark a key iOS never shows (the widget's `CFBundleName`) Don't Translate. Give a new count its English `one` and `other` forms, and delete the stale keys: changed English is a new key, and the old one's translations no longer apply.
3. **Translate.** `make l10n-translate` (`LANGS="de ja"` for some languages only) sends the AI only what is missing, empty, flagged for review or broken, with `l10n/context.md`, the translator brief, and `l10n/languages/<code>.md`, the language's style guide. It validates every reply (placeholders, plural forms) and asks again when one fails.
4. **Review** every new translation against its language's style guide. To change one, `node scripts/l10n.ts export --lang <code> --out <file>` (`--force` for every string, not just those that need work), edit the `translation` of the units you mean to change, delete the rest, and `node scripts/l10n.ts import --lang <code> <file>`, which validates them as `translate` does. The same two commands let a person or another AI translate or review a whole language. Never shorten the English to make a translation fit.
5. **Check and commit.** `node scripts/l10n.ts check` must pass. Commit the catalogue, translations included, with the code that changed it. When the app gains a term, or one decision turns up in several style guides, add it to the brief's glossary; a decision for one language belongs in its style guide.

The tool writes catalogues byte for byte as Xcode's catalogue editor does, so Xcode re-saving them changes nothing, and `normalise` puts a catalogue back in that format. `make test-scripts` runs its tests, with the other scripts'.

### Add a language

1. Run `make l10n-add-language CODE=<code>`. It adds the code to the project's `knownRegions`, the only list of languages there is, and translates everything into it. A language that was translated before and held back comes back with its reviewed translations: `node scripts/l10n.ts add-language <code> --from <commit>` restores every one whose English is unchanged and translates only the rest; `l10n/context.md` names the commit. `node scripts/l10n.ts remove-language <code>` takes a language out of `knownRegions` and every catalogue, and prints the command that brings it back.
2. Give it an App Store listing, `metadata/<locale>/` (or one per region, as Spanish has es-ES and es-MX), with the same files as `metadata/en-GB/` except `review_notes.txt`, captions in `screenshots/store/<locale>/captions.json`, and the version in preparation's changelog texts (the release skill), so What's New is generated for it.
3. Write `l10n/languages/<code>.md`, the language's style guide, with someone who speaks it at a native level: register and form of address, Apple's own terms, the glossary, punctuation, plural forms and pitfalls, as the other guides have them. Then translate again with the guide in place: `node scripts/l10n.ts translate --lang <code> --force`, and review it as in [Add or change copy](#add-or-change-copy).
4. Capture every screen in it and look, as [Check every language](#check-every-language) describes.

### Check every language

- **Screenshots.** `make capture-l10n` runs `CardsLocalisationScreenshotTests` once per language and text size and writes `/tmp/cards-l10n-qa/<language>/<size>/<screen>.png`: the list, a card's menu, the empty list, a card (and one whose barcode fails), Add Card, Edit Card, the location prompt (from the empty list, as the seeded cards' fixed place never asks) and map, a place in the form, Settings, the delete-all confirmation and the import sheet. A screen that scrolls is captured a page at a time to its end (`06-add.png`, `06-add-2.png`, …). It visits the screens through the accessibility audit's helpers (`CardsUITests/UITestNavigation.swift`), so a screen added to one belongs in the other. Narrow it with `LANGS="de ja"` and `SIZES="large AX5"` (`xs` to `xxxl`, `AX1` to `AX5`); `SIMULATOR_DEVICE="iPad Pro 13-inch (M4)" L10N_QA_OUT=/tmp/cards-l10n-qa/ipad` captures on an iPad. Each language runs in its own region (`en` in GB, `de` in DE, `ja` in JP), as `-testLanguage` and `-testRegion` would set it. The script keeps its own simulator of that device (`iPhone 16 Pro (Cards l10n QA)`) and sets its system language too, restarting it once per language, because iOS draws the location prompt, with the app's reason for asking, in the system's language rather than the app's. Outside the script the test skips itself, so `make test` never runs it.
- **What to look for.** Cut-off or overlapping text, controls pushed off screen, English left untranslated, raw keys or `%@`, mirroring right to left (codes and barcodes must not mirror), number and distance formats, and line breaks in Chinese and Japanese. Fix layout in the views, and wording that is wrong or too long through `export` and `import`.
- **The UI tests in a language.** The accessibility audit and the tests that find elements by identifier run in any language, and its default-size pass runs in that language with them: `xcodebuild test -project Cards.xcodeproj -scheme Cards -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.1' -only-testing:CardsUITests -testLanguage de`. German (long words) and Japanese (line breaks) find the most.
- **The accessibility audit.** `make test-a11y` runs it on every screen in English, and right to left at the largest text size.
- **The Storybook.** The display options menu's Language and Direction show any story in any language, either way round, at any text size, which is the quickest way to check a new view. What the language cannot switch ([rule 17](#rule-17-every-string-is-translatable-and-translated)) needs the app run in the language. The widget's face (`CardWidgetView`) switches too, as it compiles into the app with its strings; its gallery name, description and settings are drawn by iOS from the widget's own bundle, so check those on the Home Screen of a simulator set to the language.

### Change the app icon

Edit `DesignAssets/Icon.svg`, run `node scripts/generate-app-icons.ts`, and commit the SVG with the regenerated PNGs.

### Mark a change

Ask for the release skill ("mark the changes"), or follow [.claude/skills/release/SKILL.md](../.claude/skills/release/SKILL.md) by hand: add the entries to `changelog.json`, update `spec/`, then run `node scripts/generate-changelog.ts` and `node scripts/check-changelog.ts`. The first change after a release starts the next version, which means bumping `MARKETING_VERSION` too.

### Publish a new App Store version

The release skill runs these steps; they are here for reference.

1. Set `MARKETING_VERSION` in the project-level build settings to the new version (for example `1.3`); the app and the widget inherit it, and App Store Connect rejects an extension whose version differs from its app. Commit and push, and wait for CI to pass.
2. Tag the commit with an annotated tag whose name matches the version and whose message is its What's New from the changelog, then push the tag:
   ```bash
   git tag -a v1.3 -F <(node scripts/print-release-notes.ts 1.3)
   git push origin v1.3
   ```
3. `release.yml` runs `scripts/release-version.ts`, which stamps a build number, archives, signs and uploads (`scripts/build-ipa.ts`, `scripts/upload-build.ts`), waits for Apple to process the build, creates the App Store version, attaches the build, sets "What's New" in every localisation and submits it for review (`scripts/submit-for-review.ts`). A tag without a message stops the workflow before it uploads anything.
5. The store listing (text and screenshots) is separate: see [Update the App Store listing](#update-the-app-store-listing).

### Update the App Store listing

Everything on the App Store product page lives in the repository, so it can be changed in a commit and pushed with one workflow.

- **Text:** `metadata/<locale>/`: `name.txt` (30 characters), `subtitle.txt` (30), `keywords.txt` (100 bytes, comma-separated, no words already in the name or subtitle), `promotional_text.txt` (170), `description.txt` (4,000), `release_notes.txt` ("What's New", 4,000, generated from the changelog in each locale's language), and the URLs, plus `review_notes.txt` for App Review in `en-GB` alone: App Store Connect keeps one set per version, and check-metadata fails on a copy anywhere else. `node scripts/check-metadata.ts` (`make check-metadata`) checks every limit, and CI runs it. Write en-GB in British English and en-US in American, and keep both saying the same thing. Every other locale says the same in its own words, in its style guide's register (`l10n/languages/`): local copy rather than word for word, with the name's part after the colon and the keywords chosen for what people search for there. Names, subtitles, screenshot captions and the creative asset's title never mention the price (Guideline 2.3.7), which check-metadata and check-store-images enforce; the description and promotional text may say it is free. The annotated release tag's message should match `release_notes.txt`.
- **Raw screenshots:** `make capture-screenshots` (about half an hour) captures each screen on the iPhone 17 Pro Max, iPad Pro 13-inch and iPhone Duo simulators in every store locale, into `screenshots/<locale>/`, each in its language and region, with the status bar at 9:41. `CardsScreenshotTests` takes the list, a card, the edit form and the map in one run through the app (`testCaptureScreenshots`), and a card with its share menu open, offering Share Link and Share Image (`testCaptureShareScreenshot`, `06_ShareCard`); `CardsWidgetScreenshotTests` adds the widget to the Home Screen as a person would and keeps a band of the screen round it. Once everything is captured, `node scripts/check-screenshots.ts` (`make check-screenshots`) checks that every locale has every screen on every device at the right size. A screen added to the tests since the last capture has no PNGs yet; the check reports it as not captured yet and passes, and once any capture of it exists it must be complete. CI never captures or compares raw screenshots. Look at every changed PNG and commit them in their own `test:` commit. To add a screen, take it in a UI test and add its name to `screens` in both `capture-screenshots.ts` and `check-screenshots.ts`.
- **Store images:** CI only checks that they are all present (`node scripts/check-store-images.ts`). Capturing, composing and looking at them is local work, done and checked before they are committed. `make store-screenshots` composes what is uploaded: `screenshots/store/<locale>/`, one image per entry in that folder's `captions.json` for each device, and the universal creative asset. A caption entry names the image (`file`), the raw capture it shows (`screen`), a card colour for the background (`color`), a `title` and `subtitle`, and a `layout`: `screen` frames a whole screen, `band` shows a strip such as the widget's edge to edge. Edit the captions or order, run it again and look at the result. The composer is `Cards/Development/StoreScreenshot.swift`, rendered by `StoreScreenshotTests`, which only runs when `make store-screenshots` turns it on.
- **Creative asset:** iOS 27 and iPadOS 27 show one universal creative asset, a 16:9 PNG of 5244 × 2950 with no alpha channel, as both the product page header and the search result. Each locale's `creative-asset.json` describes it: the image's name (`file`, `CreativeAsset`), the iPhone raw capture the phone shows (`screen`, the card screen), a card colour for the background (`color`) and the one short line beside the phone (`title`), which is translated like the captions. `Cards/Development/StoreCreativeAsset.swift` composes it, with the line and the phone inside the centre safe area of Apple's universal asset template (1402 × 962 at 1921, 660: the "Art Safe Area" layer of the template linked from [Apple's asset best practices](https://developer.apple.com/app-store/asset-best-practices/)); only the empty lower part of the phone runs on below it. Apple's rules for these assets: a single, clear idea, a short phrase that enhances the picture rather than describes it, localised for every language, and no prices, discounts, URLs or copyright symbols, so never "free" (guideline 2.3.14). To review it without rendering, open **Development > Storybook > Store > StoreCreativeAsset** in the simulator: it reads each locale's `creative-asset.json` from the repository and draws the asset scaled down, with the safe area outlined (the **Safe area** knob), the phone showing a stand-in Joe's Market card or the committed raw capture (**Screen**), and another background colour to try (**Colour**). Before the release capture, the committed raw captures can be out of date, which is why the stand-in is the default. `check-store-images.ts` requires the asset in every locale once any locale has a `creative-asset.json`, at its exact size and with no alpha channel.
- **Uploading:** after pushing, run the **App Store listing** workflow (Actions tab, or `gh workflow run app-store-listing.yml`). It updates the editable App Store version: with **prepare version** and a version number it first gives the editable version that number, or creates it, then uploads the text and makes each display type's screenshots match `screenshots/store/`: images already there with the same name and checksum are kept, the rest are sent, and it waits for Apple to process them all. Apple can take a quarter of an hour per image on a slow day, so if a run reports images still processing, run it again later: it sends nothing new and reports their state. `--replace` sends everything again. Last, it uploads each locale's creative asset (`scripts/upload-creative-assets.ts`) to the app's asset library, which App Store Connect API 4.5.1 added, and places it on that localisation as both the product page header and the search results asset, in every placement group App Store Connect's reference data maps to the universal 5244 × 2950 specification. An image already in the library with the same bytes is not sent again, a placement already showing it is kept, and any other placement in its group is replaced; the placements go to App Review with the version. Untick **creative assets** to leave them alone. Then open the version in App Store Connect and use its preview of the header and search results, on iPhone and iPad and in each orientation, before submitting. Tick **dry run** to see what would change. `make upload-metadata`, `make upload-screenshots` and `make upload-creative-assets` do the same parts locally, given an API key in the environment.
- **Screenshot sizes:** iPhone 6.9" 1320 × 2868 (App Store Connect scales them for smaller iPhones), iPad 13" 2064 × 2752, and iPhone Duo's outer display 1398 × 2034 (the simulator boots folded; App Store Connect also takes the inner display's 2007 × 2853). The Duo display type is `APP_IPHONE_DUO`, which App Store Connect accepts although the published API spec does not list it yet. Images must have no alpha channel.

## 6. Running and driving the simulator

Xcode 27 has no Simulator.app; `make sim` opens Device Hub to show the screen, and every `simctl` command works headless.

- **Launch arguments:** `-uiTesting` gives an in-memory store and hides the Development tab; `-screenshotSeed` adds the six screenshot cards; `-initializeCloudKitSchema` creates the CloudKit schema in the Development environment ([section 8](#8-releasing)). The environment variables `CARDS_UI_TESTING=1` and `CARDS_SCREENSHOT_SEED=1` do the same as the first two. All of them are ignored in release builds.
- **Deep links:** `cards://cards/card/<code>`, `cards://cards/card/<code>/edit` and `cards://cards/new`, with the code percent-encoded (`NavigationRoute.url` builds them), and `cards://cards/add#<payload>` for a shared card, the app-scheme twin of the `https://cards.serby.net/add#<payload>` share link (`SharedCardLink.appURL` builds it). `xcrun simctl openurl` shows a confirmation prompt first.
- **The widget:** open the app once so it writes the snapshot, then long-press the Home Screen, tap **Edit > Add Widget**, find Card Barcodes and add the medium size. Long-press the widget and choose **Edit Widget** to pick a card instead of the nearest one. Its views are also in the Storybook (`CardWidgetView`), which is quicker for layout work.
- **Location:** `xcrun simctl privacy <udid> grant location net.serby.Cards`, then `xcrun simctl location <udid> set 51.5203,-0.2094`.
- **Arrival notifications:** Settings > Arrival Notifications (the `arrivalNotifications` user default, on unless turned off) decides whether any are scheduled; turning it off cancels them all. To try one, give a card a location, send the app to the background, set the simulated location away and then back inside the circle; SpringBoard logs `Location trigger fired` when it delivers. To see a card's notification without moving, use **Development > Test Notification** in a debug build launched without `-uiTesting`: tapping a card sends its arrival notification five seconds later.
- **The review prompt:** the app asks for a rating on coming back from a card to the list, once cards have been opened on three days in the version (PLAT-8). Development > Review Prompt shows the counts and can ask now, make it due on the next return, or start again; a debug build shows Apple's prompt on every request. UI tests and screenshot runs never ask (`DevelopmentHooks.asksForReviews`).
- **Reinstalling:** uninstall before installing. `simctl install` over a running copy can keep the old binary, and you end up debugging a build you are not running.
- **On an iPhone:** build with `xcodebuild … -destination 'id=<udid>' -allowProvisioningUpdates build`, install with `xcrun devicectl device install app --device <udid> <path to Cards.app>`, and run with `DEVICECTL_CHILD_OS_ACTIVITY_DT_MODE=enable xcrun devicectl device process launch --console --terminate-existing --device <udid> net.serby.Cards`. `OS_ACTIVITY_DT_MODE` copies the app's system log into the console, as Xcode does. Put app arguments after `--` (`… net.serby.Cards -- -initializeCloudKitSchema`), or devicectl reads them as its own options. The phone must be unlocked.

## 7. Signing, teams and iCloud

- The app ID `net.serby.Cards` and the iCloud container `iCloud.net.serby.Cards` belong to the paid Apple Developer team **"Paul Serby" (`ZMBFPG86J4`)**. Both build configurations of the app target must use that team, and so must anyone building to a device.
- A **Personal Team cannot build this app**. Free teams do not support the iCloud capability, and the app ID belongs to another team, so Xcode fails with "Personal development teams … do not support the iCloud capability" and "doesn't include the iCloud capability".
- Every Apple ID comes with a free Personal Team, so "Paul Serby (Personal Team)" in the team menu is not the paid team; it belongs to whichever Apple ID is signed in, which may be a work one. If the menu has no plain "Paul Serby", the Apple ID that owns the paid team is not signed in to Xcode.
- To build to a device, sign in to Xcode (**Settings > Accounts**) with the Apple ID that is a member of `ZMBFPG86J4`, select that team in **Signing & Capabilities** for both configurations, and let Xcode register the device and create the development profile.
- The widget is `net.serby.Cards.Widget`, and it shares the App Group `group.net.serby.Cards` with the app. Xcode registered both, and assigned the group to both App IDs, on the first device build with automatic signing. Do that again (`make device`) after adding a capability: the App Store Connect API cannot assign App Groups.
- CI keeps no provisioning profiles. `.github/actions/install-signing` imports the distribution certificate (`scripts/install-signing-certificate.ts`) and runs `scripts/install-signing-profiles.ts`, which installs an App Store profile per bundle ID named `Cards CI App Store <bundle ID>`, creating it, or replacing it when Apple has invalidated it after a capability change. `scripts/build-ipa.ts` signs with those names.
- Never sign this app with a company team you happen to belong to.
- Debug builds use `Cards/Cards.Debug.entitlements`, which points at the **Development** CloudKit environment, and Release builds use `Cards/Cards.entitlements`, which points at **Production**. A debug build on your own iPhone therefore syncs a separate set of cards from the App Store app, and can never damage the live data.
- Share links (SHARE-1) are universal links: both entitlements files claim `applinks:cards.serby.net`, and the website serves `Website/src/.well-known/apple-app-site-association` for team `ZMBFPG86J4`, app `net.serby.Cards`, path `/add` (with a `_headers` rule so Cloudflare Pages serves it as JSON). The App ID needs the Associated Domains capability before a device build or CI signing works; `make device` signed in to the paid team turns it on, or tick it on the App ID in the developer portal. CI then replaces the invalidated profile on its next run. Simulator builds need neither, and `cards://cards/add#…` opens the same sheet without them.
- CloudKit change pushes are not enabled yet: the app has neither the `remote-notification` background mode nor the Push Notifications capability, so other devices' changes arrive when the app is opened rather than straight away (CloudKit logs "BUG IN CLIENT OF CLOUDKIT: … require the 'remote-notification' background mode"). Enabling it changes the App ID; add the capability with a device build, and CI replaces the invalidated profile on its next run.
- `scripts/build-ipa.ts` passes `DEVELOPMENT_TEAM` (default `ZMBFPG86J4`) itself, so archives do not depend on the project's team setting.

## 8. Releasing

1. Push to `main` (rule 10). CI runs the build and the unit tests, the release check, and the metadata, changelog and store image checks, in parallel. It does not capture screenshots or run UI tests or SwiftLint, so the local loop is the real check. Nothing is uploaded on a push.
2. If the build adds stored fields, deploy the CloudKit schema first; Production rejects records whose type or fields it does not have, with "Cannot create new type … in production schema" or "Cannot create or modify field …". Launch a Debug build once with `-initializeCloudKitSchema`, on a device or simulator signed in to iCloud, and wait for the log line "CloudKit schema initialised in the Development environment". Then open the [CloudKit Console](https://icloud.developer.apple.com/dashboard/), choose `iCloud.net.serby.Cards`, and use **Deploy Schema Changes** to copy the Development schema to Production.
3. `make upload-build` archives with `scripts/build-ipa.ts` and uploads with an App Store Connect API key (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`). In CI, `release.yml` builds, uploads and submits to the App Store on `v*` tags. There is no TestFlight upload in CI; run `make upload-build` to put a build on TestFlight by hand.
4. The **App Store listing** workflow pushes the listing text from `metadata/` and the store images from `screenshots/store/` ([section 5](#update-the-app-store-listing)).

`.github/workflows/ci.yml`, `release.yml` and `app-store-listing.yml` are the source of truth for the pipelines; `docs/CICD_SETUP.md` and `docs/DEPLOYMENT.md` cover the one-off account and secrets setup.

## 9. Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| "Personal development teams … do not support the iCloud capability" | The project's team is a Personal Team. Use `ZMBFPG86J4` ([section 7](#7-signing-teams-and-icloud)) |
| "Device … isn't registered in your developer account" | Building to a device or "My Mac (Designed for iPad)" with a team that has not registered it. Select `ZMBFPG86J4`; Xcode offers to register it |
| Release build fails with "has no member 'sample'" or similar | Production code, often a preview left beside a view, names something in `Cards/Development`. Move the preview or go through `DevelopmentHooks` |
| `make check-release` lists a declaration | That development type or member is reachable from production code. Find the reference and route it through a hook |
| `install-signing-profiles.ts` fails with "No App ID net.serby.Cards.Widget" | The App ID or its App Group is not registered. Run `make device` once, signed in to the paid team, so Xcode registers them |
| Upload fails because the extension's `CFBundleVersion` or `CFBundleShortVersionString` differs from the app's | A version was set on one target or in an Info.plist. Keep both in the project-level build settings, and pass build numbers as `BUILD_NUMBER` |
| Cards are missing after an update | The store moved. Build the container with `CardStore.configuration` ([rule 6](#rule-6-models-stay-cloudkit--and-export-compatible)) |
| The app behaves like an older build | `simctl install` kept the old binary; uninstall, then install |
| A build fails in `PrecompileModule` with "cannot find interface declaration" | Stale generated `*-Swift.h` headers after a type was deleted; delete them under `fastlane/derived_data/Build/Intermediates.noindex` and rebuild |
| "Cannot create new type CD_CardItem in production schema" in the log | The Production CloudKit schema is missing the model; deploy it ([section 8](#8-releasing)) |
| The map picker freezes the app | Something updates `Map` content from `onMapCameraChange` ([rule 7](#rule-7-swift-6-no-warnings-clean-lint)) |
| A story shows several Edit buttons | The screen story is missing `galleryLayout: .oneAtATime` |
| The Storybook's Language menu lists a language that has no translations | When a language's last translation goes, Xcode leaves its empty `.lproj` folder in the built app and the bundle still lists it. Delete the folder from `Cards.app` in `BUILT_PRODUCTS_DIR`, or clean the build folder in Xcode |
| New copy is missing from `Localizable.xcstrings` | Command-line builds never write to catalogues; run `xcodebuild -exportLocalizations` ([Add or change copy](#add-or-change-copy)) |
| Storybook or preview text turns up in `Localizable.xcstrings` | A literal reached a `LocalizedStringKey` in `Cards/Development`; make it `Text(verbatim:)` or a `String` |
| An English device shows a translation | `Info.plist` must keep `CFBundleDevelopmentRegion`: catalogues compile no `en.lproj` for unchanged English, so without it iOS picks one of the translations |
