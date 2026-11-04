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
| Xcode 27.1 | Builds, tests, simulators | The Makefile and scripts use `XCODE_APP` if set, else `/Applications/Xcode27.1.app` when it is installed, else whatever `xcode-select` points at, as on CI runners (`scripts/xcode-env.sh`) |
| SwiftLint | Lint, run before every build | `.swiftlint.yml` at the root |
| Node 24 | `scripts/check-release-clean.ts` | Runs TypeScript directly, no install step |
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
| `make test-tsan` | Unit tests under the thread sanitiser |
| `make test-coverage` | Tests plus an HTML coverage report in `coverage-html/` |
| `make check-release` | Build Release and fail if any development code reached it ([rule 1](#rule-1-development-code-never-ships)) |
| `make sim` | Build, boot the simulator, install and launch |
| `make device` | Build and install on a connected iPhone |
| `make capture-screenshots` | Refresh the en-US and en-GB iPhone and iPad App Store screenshots |
| `make validate-screenshots` | Check the committed screenshot set |
| `make deploy-testflight`, `make deploy-appstore` | Archive, export and upload |

Override `SIMULATOR_DEVICE` and `SIMULATOR_VERSION` on the command line to target another simulator.

Xcode on this project writes build products to `fastlane/derived_data/Build/Products` (a custom build location preference), not to `-derivedDataPath`. Never guess the path; ask: `xcodebuild -project Cards.xcodeproj -scheme Cards -showBuildSettings | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p'`.

## 3. Project layout

One app target and one widget extension. The app is a single Swift module whose folders are layers by convention, so the compiler will not stop a violation; the rules in section 4 do.

```
Cards/
  App/           Entry point, and DevelopmentHooks: the only door into Development
  Core/          Models, navigation and services. No SwiftUI views
    Models/        CardItem (SwiftData), CardItemDTO, BarcodeType, CardColor, CardLocation, WidgetCard
    Navigation/    NavigationRoute, NavigationManager, deep links
    Services/      CardStore, LocationService, PostcodeLookup, PerformanceTracker, WidgetSnapshot
  UI/            Every view, as a pure function of view state and actions
    Screens/       CardListView, CardDetailView, CardEditView, LocationPickerView, SettingsListView
    Components/    BarcodeView, BarcodeImage, CardColorPicker, CardLocationRow, CardWidgetView, ProximityLabel, …
    ViewState/     CardSummary, CardDetail, CardDraft, CardWidgetState, SettingsState
    Actions/       Closure bundles each screen raises
    Environment/   Injected effects: ScreenBrightness, AccessibilityAnnouncer
    Theme/         Colours, the card palette
  Scanner/       Camera scanning (AVFoundation), pinch to zoom
  Features/      Connectors: SwiftData, navigation, location and notifications in, view state out
  Development/   Never in a release build. Storybook, previews, sample data, stand-ins, test seeds
CardsWidget/     The Home Screen widget extension: timeline, configuration intents, location
CardsTests/      Unit tests (Swift Testing)
CardsUITests/    UI and screenshot tests (XCTest)
```

The widget cannot open the SwiftData store, so the list screen writes every card to a JSON file in the App Group container (`WidgetSnapshot`) and the widget reads that. The widget compiles a short list of files from `Cards/` (models, `BarcodeImage`, `CardWidgetView`, the palette); the list is the "Exceptions for \"Cards\" folder in \"CardsWidget\" target" set in the project, which is what Xcode's Target Membership box edits. A shared file may only use what is on that list, so keep it to Foundation, SwiftUI and other shared files.

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
- Never update `Map` content from `onMapCameraChange`: MapKit re-applies the camera and loops. Draw camera-relative overlays in screen space, as `LocationPickerView` does with its radius ring.

### Rule 8: Accessibility is part of done

- Every control a UI test touches has an `accessibilityIdentifier`; every meaningful control has a label in plain words.
- Decorative images are hidden from VoiceOver; codes are read character by character (`speechSpellsOutCharacters()`).
- Layouts survive the accessibility text sizes: switch from side by side to stacked with `AnyLayout` when `dynamicTypeSize.isAccessibilitySize`.
- Check new UI in the Storybook in dark mode, at the largest text size and right to left before calling it finished.

### Rule 9: Test the logic, the persistence and the promises

- Unit tests use Swift Testing (`@Test`, parameterised with `arguments:`); UI and screenshot tests use XCTest.
- Test pure logic directly (distances, the arrival plan, palette contrast) and persistence through a real in-memory container.
- UI tests launch with `-uiTesting` for an in-memory store and the shipping UI; the screenshot test adds `-screenshotSeed`.
- A UI change that shows up in the App Store screenshots must come with refreshed references, or CI fails.

### Rule 10: Commits tell a story, straight on `main`

- **Work on `main`.** Cards has one contributor, so there are no feature branches and no pull requests: commit to `main` and push. Pushing is the release step, because a push to `main` runs CI and, when CI passes, `deploy.yml` uploads a TestFlight build. Push when the change is ready for testers, and run the loop in section 2 first so CI is a formality.
- **Build numbers are automatic.** The deploy job passes a build number from the time on the runner to `scripts/build-ipa.sh` as `BUILD_NUMBER`, which sets `CURRENT_PROJECT_VERSION` for the app and widget together, and commits nothing back, so `main` never moves under you.
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

Add a case to `CardColor` with its raw value in `CardColor.swift`, then its hex and display name in `CardPalette.swift`, keeping the picker's rows full ([docs/STYLE.md](STYLE.md), section 3). Run `make test-unit` and adjust the colour until `CardColorTests` passes.

### Add a package dependency

In Xcode, **File > Add Package Dependencies**, add the product to the `Cards` target, and commit `project.pbxproj` with `Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

### Change the app icon

Edit `DesignAssets/Icon.svg`, run `scripts/generate-app-icons.sh`, and commit the SVG with the regenerated PNGs.

### Publish a new App Store version

1. Set `MARKETING_VERSION` in the project-level build settings to the new version (for example `1.3`); the app and the widget inherit it, and App Store Connect rejects an extension whose version differs from its app. Commit and push. Every push to `main` puts a build on TestFlight.
2. Wait for that push's CI and TestFlight deploy to finish; App Store Connect rejects two uploads arriving at once.
3. Tag the commit with an annotated tag whose name matches the version and whose message is the "What's New" text, then push the tag:
   ```bash
   git tag -a v1.3 -m "What's New text"
   git push origin v1.3
   ```
4. `release.yml` stamps a build number, archives, signs and uploads, waits for Apple to process the build, creates the App Store version, attaches the build, sets "What's New" in every localisation and submits it for review (`scripts/asc-submit.sh`). A tag without a message stops the workflow before it uploads anything.
5. The store listing (text and screenshots) is separate: see [Update the App Store listing](#update-the-app-store-listing).

### Update the App Store listing

Everything on the App Store product page lives in the repository, so it can be changed in a commit and pushed with one workflow.

- **Text:** `metadata/<locale>/`: `name.txt` (30 characters), `subtitle.txt` (30), `keywords.txt` (100 bytes, comma-separated, no words already in the name or subtitle), `promotional_text.txt` (170), `description.txt` (4,000), `release_notes.txt` ("What's New", 4,000), `review_notes.txt` for App Review, and the URLs. `node scripts/check-metadata.ts` (`make check-metadata`) checks every limit, and CI runs it. Write en-GB in British English and en-US in American, and keep both saying the same thing. The annotated release tag's message should match `release_notes.txt`.
- **Raw screenshots:** `make capture-screenshots` (about half an hour) captures each screen on the iPhone 17 Pro Max, iPad Pro 13-inch and iPhone Duo simulators in both locales, into `screenshots/<locale>/`, with the status bar at 9:41. `CardsScreenshotTests` takes the list, a card, the edit form and the map; `CardsWidgetScreenshotTests` adds the widget to the Home Screen as a person would and keeps a band of the screen round it. Look at every changed PNG and commit them in their own `test:` commit; CI compares the list, card and edit shots with them.
- **Store images:** `make store-screenshots` composes what is uploaded: `screenshots/store/<locale>/`, one image per entry in that folder's `captions.json` for each device. An entry names the image (`file`), the raw capture it shows (`screen`), a card colour for the background (`color`), a `title` and `subtitle`, and a `layout`: `screen` frames a whole screen, `band` shows a strip such as the widget's edge to edge. Edit the captions or order, run it again and look at the result. The composer is `Cards/Development/StoreScreenshot.swift`, rendered by `StoreScreenshotTests`, which only runs when `make store-screenshots` turns it on.
- **Uploading:** after pushing, run the **App Store listing** workflow (Actions tab, or `gh workflow run app-store-listing.yml`). It updates the editable App Store version: with **prepare version** and a version number it first renames that version and attaches the newest processed build of it, then uploads the text and makes each display type's screenshots match `screenshots/store/`: images already there with the same name and checksum are kept, the rest are sent, and it waits for Apple to process them all. Apple can take a quarter of an hour per image on a slow day, so if a run reports images still processing, run it again later: it sends nothing new and reports their state. `--replace` sends everything again. Tick **dry run** to see what would change. `make upload-metadata` and `make upload-screenshots` do the same parts locally, given an API key in the environment.
- **Screenshot sizes:** iPhone 6.9" 1320 × 2868 (App Store Connect scales them for smaller iPhones), iPad 13" 2064 × 2752, and iPhone Duo's outer display 1398 × 2034 (the simulator boots folded; App Store Connect also takes the inner display's 2007 × 2853). The Duo display type is `APP_IPHONE_DUO`, which App Store Connect accepts although the published API spec does not list it yet. Images must have no alpha channel.

## 6. Running and driving the simulator

Xcode 27 has no Simulator.app; `make sim` opens Device Hub to show the screen, and every `simctl` command works headless.

- **Launch arguments:** `-uiTesting` gives an in-memory store and hides the Storybook tab; `-screenshotSeed` adds the six screenshot cards; `-initializeCloudKitSchema` creates the CloudKit schema in the Development environment ([section 8](#8-releasing)). The environment variables `CARDS_UI_TESTING=1` and `CARDS_SCREENSHOT_SEED=1` do the same as the first two. All of them are ignored in release builds.
- **Deep links:** `cards://cards/card/<code>`, `cards://cards/card/<code>/edit` and `cards://cards/new`, with the code percent-encoded (`NavigationRoute.url` builds them). `xcrun simctl openurl` shows a confirmation prompt first.
- **The widget:** open the app once so it writes the snapshot, then long-press the Home Screen, tap **Edit > Add Widget**, find Card Barcodes and add the medium size. Long-press the widget and choose **Edit Widget** to pick a card instead of the nearest one. Its views are also in the Storybook (`CardWidgetView`), which is quicker for layout work.
- **Location:** `xcrun simctl privacy <udid> grant location net.serby.Cards`, then `xcrun simctl location <udid> set 51.5203,-0.2094`.
- **Arrival notifications:** Settings > Arrival Notifications (the `arrivalNotifications` user default, on unless turned off) decides whether any are scheduled; turning it off cancels them all. To try one, give a card a location, send the app to the background, set the simulated location away and then back inside the circle; SpringBoard logs `Location trigger fired` when it delivers.
- **Reinstalling:** uninstall before installing. `simctl install` over a running copy can keep the old binary, and you end up debugging a build you are not running.
- **On an iPhone:** build with `xcodebuild … -destination 'id=<udid>' -allowProvisioningUpdates build`, install with `xcrun devicectl device install app --device <udid> <path to Cards.app>`, and run with `DEVICECTL_CHILD_OS_ACTIVITY_DT_MODE=enable xcrun devicectl device process launch --console --terminate-existing --device <udid> net.serby.Cards`. `OS_ACTIVITY_DT_MODE` copies the app's system log into the console, as Xcode does. Put app arguments after `--` (`… net.serby.Cards -- -initializeCloudKitSchema`), or devicectl reads them as its own options. The phone must be unlocked.

## 7. Signing, teams and iCloud

- The app ID `net.serby.Cards` and the iCloud container `iCloud.net.serby.Cards` belong to the paid Apple Developer team **"Paul Serby" (`ZMBFPG86J4`)**. Both build configurations of the app target must use that team, and so must anyone building to a device.
- A **Personal Team cannot build this app**. Free teams do not support the iCloud capability, and the app ID belongs to another team, so Xcode fails with "Personal development teams … do not support the iCloud capability" and "doesn't include the iCloud capability".
- Every Apple ID comes with a free Personal Team, so "Paul Serby (Personal Team)" in the team menu is not the paid team; it belongs to whichever Apple ID is signed in, which may be a work one. If the menu has no plain "Paul Serby", the Apple ID that owns the paid team is not signed in to Xcode.
- To build to a device, sign in to Xcode (**Settings > Accounts**) with the Apple ID that is a member of `ZMBFPG86J4`, select that team in **Signing & Capabilities** for both configurations, and let Xcode register the device and create the development profile.
- The widget is `net.serby.Cards.Widget`, and it shares the App Group `group.net.serby.Cards` with the app. Xcode registered both, and assigned the group to both App IDs, on the first device build with automatic signing. Do that again (`make device`) after adding a capability: the App Store Connect API cannot assign App Groups.
- CI keeps no provisioning profiles. `.github/actions/install-signing` imports the distribution certificate and runs `scripts/asc-profiles.ts`, which installs an App Store profile per bundle ID named `Cards CI App Store <bundle ID>`, creating it, or replacing it when Apple has invalidated it after a capability change. `scripts/build-ipa.sh` signs with those names.
- Never sign this app with a company team you happen to belong to.
- Debug builds use `Cards/Cards.Debug.entitlements`, which points at the **Development** CloudKit environment, and Release builds use `Cards/Cards.entitlements`, which points at **Production**. A debug build on your own iPhone therefore syncs a separate set of cards from the App Store app, and can never damage the live data.
- CloudKit change pushes are not enabled yet: the app has neither the `remote-notification` background mode nor the Push Notifications capability, so other devices' changes arrive when the app is opened rather than straight away (CloudKit logs "BUG IN CLIENT OF CLOUDKIT: … require the 'remote-notification' background mode"). Enabling it changes the App ID; add the capability with a device build, and CI replaces the invalidated profile on its next run.
- `scripts/build-ipa.sh` passes `DEVELOPMENT_TEAM` (default `ZMBFPG86J4`) itself, so archives do not depend on the project's team setting.

## 8. Releasing

1. Push to `main` (rule 10). CI runs lint, the build, the release check, the tests and the screenshot comparison, and when it is green `deploy.yml` uploads to TestFlight.
2. If the build adds stored fields, deploy the CloudKit schema first; Production rejects records whose type or fields it does not have, with "Cannot create new type … in production schema" or "Cannot create or modify field …". Launch a Debug build once with `-initializeCloudKitSchema`, on a device or simulator signed in to iCloud, and wait for the log line "CloudKit schema initialised in the Development environment". Then open the [CloudKit Console](https://icloud.developer.apple.com/dashboard/), choose `iCloud.net.serby.Cards`, and use **Deploy Schema Changes** to copy the Development schema to Production.
3. `make deploy-testflight` or `make deploy-appstore` archive with `scripts/build-ipa.sh` and upload with an App Store Connect API key (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`). In CI, `deploy.yml` uploads to TestFlight after CI passes on `main`, and `release.yml` submits to the App Store on `v*` tags.
4. The **App Store listing** workflow pushes the listing text from `metadata/` and the store images from `screenshots/store/` ([section 5](#update-the-app-store-listing)).

`.github/workflows/ci.yml`, `deploy.yml` and `release.yml` are the source of truth for the pipelines; `docs/CICD_SETUP.md` and `docs/DEPLOYMENT.md` cover the one-off account and secrets setup.

## 9. Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| "Personal development teams … do not support the iCloud capability" | The project's team is a Personal Team. Use `ZMBFPG86J4` ([section 7](#7-signing-teams-and-icloud)) |
| "Device … isn't registered in your developer account" | Building to a device or "My Mac (Designed for iPad)" with a team that has not registered it. Select `ZMBFPG86J4`; Xcode offers to register it |
| Release build fails with "has no member 'sample'" or similar | Production code, often a preview left beside a view, names something in `Cards/Development`. Move the preview or go through `DevelopmentHooks` |
| `make check-release` lists a declaration | That development type or member is reachable from production code. Find the reference and route it through a hook |
| `asc-profiles.ts` fails with "No App ID net.serby.Cards.Widget" | The App ID or its App Group is not registered. Run `make device` once, signed in to the paid team, so Xcode registers them |
| Upload fails because the extension's `CFBundleVersion` or `CFBundleShortVersionString` differs from the app's | A version was set on one target or in an Info.plist. Keep both in the project-level build settings, and pass build numbers as `BUILD_NUMBER` |
| Cards are missing after an update | The store moved. Build the container with `CardStore.configuration` ([rule 6](#rule-6-models-stay-cloudkit--and-export-compatible)) |
| The app behaves like an older build | `simctl install` kept the old binary; uninstall, then install |
| A build fails in `PrecompileModule` with "cannot find interface declaration" | Stale generated `*-Swift.h` headers after a type was deleted; delete them under `fastlane/derived_data/Build/Intermediates.noindex` and rebuild |
| "Cannot create new type CD_CardItem in production schema" in the log | The Production CloudKit schema is missing the model; deploy it ([section 8](#8-releasing)) |
| The map picker freezes the app | Something updates `Map` content from `onMapCameraChange` ([rule 7](#rule-7-swift-6-no-warnings-clean-lint)) |
| A story shows several Edit buttons | The screen story is missing `galleryLayout: .oneAtATime` |
