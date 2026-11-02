# Cards

A barcode wallet for iOS. Store loyalty cards, scan barcodes with the camera, and display them at full brightness for easy scanning at the till.

Built with SwiftUI and SwiftData as a plain Xcode project.

## Quick Start

```bash
# Build
make build

# Run tests
make test

# Build, boot a simulator, install and launch
make sim

# Or just open it
open Cards.xcodeproj
```

Requires Xcode 27.1+ and an iOS 18.0+ deployment target. No other tooling to install.

## Architecture

One app target. Every source file lives under `Cards/`, which the Xcode project
picks up as a *file system synchronized group* — create a file or folder on disk
and it is in the build, with nothing to add by hand.

```
Cards/
  App/         CardsApp entry point
  Core/        Models, navigation, services (no UI)
  UI/          Every view, plus theme and barcode rendering
  Scanner/     Camera barcode scanning (AVFoundation)
  Features/    Connectors binding SwiftData and navigation to the views
  Storybook/   Debug-only browser for every view (see Storybook below)
```

The only external dependency is `RSBarcodes_Swift`, resolved by Xcode as a Swift
package. Because it is a single module there are no imports between these
folders — the grouping is organisational, and the layering below is a convention
the code follows rather than something the compiler enforces.

### Views are detached from state

Views in `UI/` never touch SwiftData, the camera, the pasteboard or screen
brightness. Each one is a function of a value type plus a set of callbacks, so it
can be rendered anywhere — previews, stories, tests — with no app running:

- **View state** (`UI/ViewState/`) — `CardSummary`, `CardDetail`, `CardDraft`,
  `SettingsState`: plain `Sendable` structs, with shared fixtures in `SampleData.swift`.
- **Actions** (`UI/Actions/`) — `CardListActions` and friends: structs of closures,
  every one defaulting to a no-op so a story supplies only what it exercises.
- **Injected effects** (`UI/Environment/`) — `ScreenBrightness` and
  `AccessibilityAnnouncer` are environment values. The app gets `.system`; stories
  get `.simulated(_:)` and `.silent`, so no story can change device brightness or
  fire VoiceOver announcements.
- **The camera is a view slot** — `CardEditView` is generic over its scanner
  subview. `Features/` passes the real `ScannerOverlayView`; stories pass
  `ScannerPlaceholderView`.

`Features/` holds everything impure. Each `*Screen` reads `@Query` /
`modelContext` / `NavigationManager`, maps models to view state, and wires the
actions back to effects. Adding a screen means adding a pure view plus a
connector, not threading a store through another view.

```
CardListScreen   -> CardListView        CardDetailScreen -> CardDetailView
CardEditScreen   -> CardEditView        SettingsScreen   -> SettingsListView
```

### Storybook

`Storybook/` is a Storybook-style browser for every view in `UI/`, reachable from
a third tab in debug builds. Each story has:

- an **Interactive** mode with live knobs (text, toggle, slider, option picker)
- a **Gallery** mode stacking the fixed variants for a visual sweep
- **display controls** applied to whichever story is showing — light/dark,
  Dynamic Type from xSmall to Accessibility 5, and right-to-left layout

Every file in `Storybook/` is wrapped in `#if DEBUG`, so a Release build compiles
none of it and the tab does not exist. Adding a story is one entry in
`Storybook/Catalogue/ComponentStories.swift` or `ScreenStories.swift`.

## Build System

A plain Xcode project, `Cards.xcodeproj`, checked into git. `xcodebuild` does the
building; the Makefile is a thin wrapper that remembers the flags.

Sources are picked up through a **file system synchronized group** on `Cards/`
(`PBXFileSystemSynchronizedRootGroup`, Xcode 16+). Add a file or a folder on disk
and it is part of the target — there is no file list in the project to maintain,
and no generator step before opening Xcode.

`RSBarcodes_Swift` is the one external dependency, resolved by Xcode as a Swift
package and pinned in
`Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Makefile Targets

`xcodebuild` invocations are long and easy to get wrong; the Makefile pins the
Xcode version, simulator device and OS in one place. Override any of
`XCODE_APP`, `SIMULATOR_DEVICE`, `SIMULATOR_VERSION` on the command line.

| Command | What it does |
|---------|-------------|
| `make build` | Build the app for the simulator |
| `make clean` | Remove build output |
| `make test` | Run unit and UI tests |
| `make test-unit` | Run `CardsTests` only |
| `make test-e2e` | Run `CardsUITests` only |
| `make test-tsan` | Run unit tests under the thread sanitiser |
| `make test-coverage` | Run tests and render an HTML coverage report |
| `make sim` | Build, boot the simulator, install and launch |
| `make device` | Build and install onto a connected iPhone |
| `make capture-screenshots` | Refresh en-US and en-GB iPhone/iPad App Store screenshots |
| `make validate-screenshots` | Validate the checked-in screenshot set and dimensions |
| `make deploy-testflight` | Archive, export and upload to TestFlight |
| `make deploy-appstore` | Archive, export and upload to the App Store |

## Screenshot Snapshots

App Store screenshots are checked in under `screenshots/<locale>/`. Refresh the
complete iPhone and iPad set with:

```bash
make capture-screenshots
```

The capture command seeds deterministic in-memory card data, fixes the simulator
status bar, exports named XCTest attachments, and validates the resulting PNG
set. To validate existing files without running a simulator:

```bash
make validate-screenshots
```

CI runs the screenshot test on an iPhone 16 Pro Max and iPad Pro 13-inch (M4),
then compares the exported captures with every en-US and en-GB reference. It
fails for missing files, wrong dimensions, invalid PNGs, or material visual
differences.

## App Icon

`DesignAssets/Icon.svg` is the master artwork (light appearance). After editing it, run `scripts/generate-app-icons.sh` to render the light, dark and tinted 1024px PNGs into `Cards/Assets.xcassets/AppIcon.appiconset` and `DesignAssets/`, plus the 180px `Website/src/icon.png`. Dark and tinted are derived by swapping the two colours to a white glyph on black. Needs `brew install librsvg imagemagick`.

## Distribution

`scripts/build-ipa.sh` archives and exports a signed `.ipa`;
`deploy-testflight.sh` and `deploy-appstore.sh` wrap it and upload with
`xcrun altool`, authenticating with an App Store Connect API key
(`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`). The `fastlane/` directory is
only a build-output location now — there are no lanes.

## Source Layout

Everything below is one module, so there are no imports between folders.

### `Cards/Core`
- `Models/` — `CardItem` (SwiftData model), `BarcodeType`, `CardItemDTO`
- `Navigation/` — `NavigationRoute`, `NavigationManager` (@Observable)
- `Services/` — `PerformanceTracker` (cold/warm start timing), `Loader`

### `Cards/UI`
Every view, with no store, camera or device access. See "Views are detached from
state" above.

- `Screens/` — `CardListView`, `CardDetailView`, `CardEditView`, `SettingsListView`
- `ViewState/` — `CardSummary`, `CardDetail`, `CardDraft`, `SettingsState`, `SampleData`
- `Actions/` — closure bundles raised by each screen
- `Environment/` — `ScreenBrightness`, `AccessibilityAnnouncer` (injected effects)
- `Components/` — `BarcodeView` (renders via RSBarcodes_Swift), `Spinner`, `ShareSheet`
- `Modifiers/`, `Theme/`, `Extensions/` — conditional modifiers, portrait lock,
  adaptive colour palette, `UIScreen.current`

### `Cards/Scanner`
- `ScannerViewController` — AVCaptureSession with metadata output
- `CameraScannerView` — SwiftUI wrapper (UIViewControllerRepresentable)

### `Cards/Features`
Connectors that bind SwiftData and navigation to the views. All the impure work
lives here: `CardListScreen`, `CardDetailScreen`, `CardEditScreen`,
`SettingsScreen`.

### `Cards/Storybook`
Debug-only story catalogue and browser, every file wrapped in `#if DEBUG`.
`Story.swift` (`Story`, `StoryKnob`, `KnobValues`), `StorybookView.swift`,
`DisplayOptions.swift`, `Stateful.swift`, and `Catalogue/`.

## CI/CD

### CI (`ci.yml`)

Runs on every push to `main` and on pull requests. Uses the `macos-26` runner.

1. Validates the checked-in screenshot set
2. Boots fixed iPhone and iPad device classes on compatible installed runtimes
3. Builds with `xcodebuild`, then runs the unit and UI tests
4. Exports screenshot attachments and compares them with all references

No toolchain install step — the project is checked in and Xcode resolves the one
Swift package itself.

### Deploy (`deploy.yml`)

Runs after CI succeeds on `main`, on version tags (`v*`), or manual dispatch.

1. Bumps `CFBundleVersion` in `Info.plist`
2. Installs the Apple certificate and provisioning profile from secrets
3. Runs `scripts/deploy-testflight.sh` (archive, export, upload)

Required GitHub secrets: `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `BUILD_PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD`, `APPLE_ID`, `ITC_TEAM_ID`, `TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`.

## Project Files

| File | Purpose |
|------|---------|
| `Cards.xcodeproj` | The project. Tracked in git; `project.pbxproj` and the shared `Cards` scheme are the only parts committed |
| `Info.plist` | App metadata; `INFOPLIST_FILE` for the app target, with `$(MARKETING_VERSION)` substituted at build time |
| `Cards/Cards.entitlements` | iCloud/CloudKit entitlements |
| `.swiftlint.yml` | SwiftLint configuration |

## Development

### Opening in Xcode

```bash
open Cards.xcodeproj
```

No generator step. The project is checked in and ready to open.

### Adding a source file

Create it anywhere under `Cards/`. The synchronized group picks it up, so there
is nothing to add to the project and no command to run. Same for new folders.

Tests work the same way: drop a file in `CardsTests/` or `CardsUITests/`.

### Adding an external dependency

In Xcode: **File > Add Package Dependencies**, then add the product to the
`Cards` target. Commit the updated `project.pbxproj` and the `Package.resolved`
under `Cards.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`.
