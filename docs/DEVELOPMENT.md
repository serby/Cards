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
5. `make capture-screenshots` and `make store-screenshots` when a change to what the screenshots show is agreed to ship (above), then look at every changed PNG before committing it

| Command | What it does |
|---------|-------------|
| `make build` | Build the app (Debug) for the simulator |
| `make test` | Unit and UI tests |
| `make test-unit` | `CardsTests` only |
| `make test-e2e` | `CardsUITests` only |
| `make test-tsan` | Unit tests under the thread sanitiser |
| `make test-coverage` | Tests on iPhone and iPad plus an HTML coverage report in `coverage-html/` |
| `make coverage-report` | The report from the last coverage run, without testing again |
| `make check` | The quick checks: metadata, changelog, raw screenshots and store images |
| `make check-release` | Build Release and fail if any development code reached it ([rule 1](#rule-1-development-code-never-ships)) |
| `make sim` | Build, boot the simulator, show it in Device Hub, install and launch |
| `make device` | Build and install on a connected iPhone |
| `make capture-screenshots` | Capture the raw screenshots on iPhone, iPad and iPhone Duo in en-US and en-GB |
| `make store-screenshots` | Compose the App Store images and the creative asset from the raw screenshots, their captions and `creative-asset.json` |
| `make check-screenshots` | Check the raw captures and that every store image is present |
| `make upload-build` | Archive, export and upload a build to App Store Connect |

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

Every main view, each screen, connector and reusable component, also has an Xcode preview, for the canvas while you work on it. Stories explore every parameter; previews show only the few states worth seeing at a glance.

- **Where:** at the bottom of the view's own file, in one `#if DEBUG … #endif` block, so the canvas shows them as you edit the view and they never ship (rule 1).
- **What:** one to three named `#Preview`s of the states that matter, such as "Barcode" and "QR code", or "New card", "Already here" and "Unreadable link". Build them from `SampleData.swift`, and use `@Previewable @State` for bindings.
- **Effects:** give previews the same stand-ins as stories (`.simulated`, `.silent`), and give connectors an in-memory model container and any environment objects they need.
- **Not needed** for private subviews and small pieces of one view, such as a row inside a list, or for the live camera scanner.

### Rule 5: Follow the visual style guide

[docs/STYLE.md](STYLE.md) is the style guide: corners nest (an inset shape takes the outer radius minus the inset, with the radii in `UI/Theme/CardGeometry.swift`), text on a card colour is readable by construction (a white panel, or the colour's ink over its readable gradient), colours come from the palette or the custom picker, and card faces use the colour's gradient. `CardColorTests` checks WCAG AA (4.5:1) for every palette colour's ink, for text on the gradient of any colour, and for the accent; `CardGeometryTests` checks the radii nest. If a test fails, change the colour, never the threshold.

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
- Decorative images are hidden from VoiceOver; codes are read character by character (`speechSpellsOutCharacters()`).
- Layouts survive the accessibility text sizes: switch from side by side to stacked with `AnyLayout` when `dynamicTypeSize.isAccessibilitySize`.
- Check new UI in the Storybook in dark mode, at the largest text size and right to left before calling it finished.

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

`changelog.json` is the one record of what changed for the people using the app, newest version first. `node scripts/generate-changelog.ts` writes `CHANGELOG.md` and each locale's `metadata/<locale>/release_notes.txt` from it, the app bundles it for Settings > What's New, and CI's `node scripts/check-changelog.ts` fails when a generated file is stale or the newest version is not the app's. The release skill ([.claude/skills/release/SKILL.md](../.claude/skills/release/SKILL.md)) is the standard way to add entries, from the commits, and to release a version. Never edit `CHANGELOG.md` or `release_notes.txt` by hand.

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

Add a case to `CardColor` with its raw value in `CardColor.swift`, then its hex and display name in `CardPalette.swift`, keeping the picker's rows full ([docs/STYLE.md](STYLE.md), section 3). Run `make test-unit` and adjust the colour until `CardColorTests` passes.

### Add a package dependency

In Xcode, **File > Add Package Dependencies**, add the product to the `Cards` target, and commit `project.pbxproj` with `Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

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

- **Text:** `metadata/<locale>/`: `name.txt` (30 characters), `subtitle.txt` (30), `keywords.txt` (100 bytes, comma-separated, no words already in the name or subtitle), `promotional_text.txt` (170), `description.txt` (4,000), `release_notes.txt` ("What's New", 4,000), `review_notes.txt` for App Review, and the URLs. `node scripts/check-metadata.ts` (`make check-metadata`) checks every limit, and CI runs it. Write en-GB in British English and en-US in American, and keep both saying the same thing. The annotated release tag's message should match `release_notes.txt`.
- **Raw screenshots:** `make capture-screenshots` (about half an hour) captures each screen on the iPhone 17 Pro Max, iPad Pro 13-inch and iPhone Duo simulators in both locales, into `screenshots/<locale>/`, with the status bar at 9:41. `CardsScreenshotTests` takes the list, a card, the edit form and the map in one run through the app (`testCaptureScreenshots`), and a card with its share menu open, offering Share Link and Share Image (`testCaptureShareScreenshot`, `06_ShareCard`); `CardsWidgetScreenshotTests` adds the widget to the Home Screen as a person would and keeps a band of the screen round it. Once everything is captured, `node scripts/check-screenshots.ts` (`make check-screenshots`) checks that every locale has every screen on every device at the right size. A screen added to the tests since the last capture has no PNGs yet; the check reports it as not captured yet and passes, and once any capture of it exists it must be complete. CI never captures or compares raw screenshots. Look at every changed PNG and commit them in their own `test:` commit. To add a screen, take it in a UI test and add its name to `screens` in both `capture-screenshots.ts` and `check-screenshots.ts`.
- **Store images:** CI only checks that they are all present (`node scripts/check-store-images.ts`). Capturing, composing and looking at them is local work, done and checked before they are committed. `make store-screenshots` composes what is uploaded: `screenshots/store/<locale>/`, one image per entry in that folder's `captions.json` for each device, and the universal creative asset. A caption entry names the image (`file`), the raw capture it shows (`screen`), a card colour for the background (`color`), a `title` and `subtitle`, and a `layout`: `screen` frames a whole screen, `band` shows a strip such as the widget's edge to edge. Edit the captions or order, run it again and look at the result. The composer is `Cards/Development/StoreScreenshot.swift`, rendered by `StoreScreenshotTests`, which only runs when `make store-screenshots` turns it on.
- **Creative asset:** iOS 27 and iPadOS 27 show one universal creative asset, a 16:9 PNG of 5244 × 2950 with no alpha channel, as both the product page header and the search result. Each locale's `creative-asset.json` describes it: the image's name (`file`, `CreativeAsset`), the iPhone raw capture the phone shows (`screen`, the card screen), a card colour for the background (`color`) and the one short line beside the phone (`title`), which is translated like the captions. `Cards/Development/StoreCreativeAsset.swift` composes it, with the line and the phone inside the centre safe area of Apple's universal asset template (1402 × 962 at 1921, 660: the "Art Safe Area" layer of the template linked from [Apple's asset best practices](https://developer.apple.com/app-store/asset-best-practices/)); only the empty lower part of the phone runs on below it. Apple's rules for these assets: a single, clear idea, a short phrase that enhances the picture rather than describes it, localised for every language, and no prices, discounts, URLs or copyright symbols, so never "free" (guideline 2.3.14). To review it without rendering, open **Development > Storybook > Store > StoreCreativeAsset** in the simulator: it reads each locale's `creative-asset.json` from the repository and draws the asset scaled down, with the safe area outlined (the **Safe area** knob), the phone showing a stand-in Joe's Market card or the committed raw capture (**Screen**), and another background colour to try (**Colour**). Before the release capture, the committed raw captures can be out of date, which is why the stand-in is the default. `check-store-images.ts` requires the asset in every locale once any locale has a `creative-asset.json`, at its exact size and with no alpha channel.
- **Uploading:** after pushing, run the **App Store listing** workflow (Actions tab, or `gh workflow run app-store-listing.yml`). It updates the editable App Store version: with **prepare version** and a version number it first gives the editable version that number, or creates it, then uploads the text and makes each display type's screenshots match `screenshots/store/`: images already there with the same name and checksum are kept, the rest are sent, and it waits for Apple to process them all. Apple can take a quarter of an hour per image on a slow day, so if a run reports images still processing, run it again later: it sends nothing new and reports their state. `--replace` sends everything again. Tick **dry run** to see what would change. `make upload-metadata` and `make upload-screenshots` do the same parts locally, given an API key in the environment.
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
