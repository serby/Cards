# Cards

A barcode wallet for iOS. Store loyalty cards, scan barcodes with the camera, and display them at full brightness for easy scanning at the till.

Built with SwiftUI, SwiftData, and structured as an SPM monorepo with Bazel.

## Quick Start

```bash
# Build
make build

# Run unit tests
make test-unit

# Build and launch in Device Hub
make sim

# Generate Xcode project (run after changing BUILD files)
make xcodeproj
```

Requires Xcode 27.1+, [Bazelisk](https://github.com/bazelbuild/bazelisk), and iOS 18.0+ deployment target.

## Architecture

Five SPM packages under `Packages/`, each with its own `Package.swift` and Bazel `BUILD` file:

```
Packages/
  CardsCore/         Models, navigation, services (no UI dependencies)
  CardsUI/           All views, plus theme and barcode rendering
  CardsScanner/      Camera barcode scanning (AVFoundation)
  CardsFeatures/     Connectors binding SwiftData and navigation to the views
  CardsStorybook/    Debug-only browser for every view (see Storybook below)
```

Dependency graph:

```
CardsStorybook → CardsCore, CardsUI
CardsFeatures  → CardsCore, CardsUI, CardsScanner
CardsUI        → CardsCore, RSBarcodes_Swift
CardsScanner   → CardsCore
CardsCore      → (Foundation, SwiftData, SwiftUI, AVFoundation)
```

The app target lives in `Cards/App/CardsApp.swift` and imports `CardsCore` + `CardsFeatures`.

### Views are detached from state

Views in `CardsUI` never touch SwiftData, the camera, the pasteboard or screen
brightness. Each one is a function of a value type plus a set of callbacks, so it
can be rendered anywhere — previews, stories, tests — with no app running:

- **View state** (`ViewState/`) — `CardSummary`, `CardDetail`, `CardDraft`,
  `SettingsState`: plain `Sendable` structs, with shared fixtures in `SampleData.swift`.
- **Actions** (`Actions/`) — `CardListActions` and friends: structs of closures,
  every one defaulting to a no-op so a story supplies only what it exercises.
- **Injected effects** (`Environment/`) — `ScreenBrightness` and
  `AccessibilityAnnouncer` are environment values. The app gets `.system`; stories
  get `.simulated(_:)` and `.silent`, so no story can change device brightness or
  fire VoiceOver announcements.
- **The camera is a view slot** — `CardEditView` is generic over its scanner
  subview. `CardsFeatures` passes the real `ScannerOverlayView`; stories pass
  `ScannerPlaceholderView`.

`CardsFeatures` holds everything impure. Each `*Screen` reads `@Query` /
`modelContext` / `NavigationManager`, maps models to view state, and wires the
actions back to effects. Adding a screen means adding a pure view plus a
connector, not threading a store through another view.

```
CardListScreen   → CardListView        CardDetailScreen → CardDetailView
CardEditScreen   → CardEditView        SettingsScreen   → SettingsListView
```

### Storybook

`CardsStorybook` is a Storybook-style browser for every view in `CardsUI`,
reachable from a third tab in debug builds. Each story has:

- an **Interactive** mode with live knobs (text, toggle, slider, option picker)
- a **Gallery** mode stacking the fixed variants for a visual sweep
- **display controls** applied to whichever story is showing — light/dark,
  Dynamic Type from xSmall to Accessibility 5, and right-to-left layout

The tab is gated on `--compilation_mode=opt`, which the deploy scripts use, so the
storybook is neither compiled nor linked into anything shipped. Verify with:

```sh
bazel cquery 'deps(//Cards:Cards.library)' --compilation_mode=opt | grep -c Storybook  # 0
```

Adding a story is one entry in `Catalogue/ComponentStories.swift` or
`Catalogue/ScreenStories.swift`.

## Build System

Three tools, each with a distinct role:

| Tool | Purpose |
|------|---------|
| **Bazel** | Compiles, links, signs, and produces the `.ipa`. Handles all build graph resolution and caching. |
| **Makefile** | Developer ergonomics. Wraps Bazel commands with the correct simulator flags so you don't have to remember them. |
| **Fastlane** | Uploads to App Store Connect (TestFlight and App Store). Bazel builds the binary; Fastlane handles the last mile. |

### Why Bazel

SPM and Xcode's build system work, but Bazel offers:
- Hermetic builds with a content-addressed disk cache
- Significantly faster incremental and no-change builds
- Reproducible CI builds (no "works on my machine")
- `rules_xcodeproj` generates the Xcode project from BUILD files

### Why Fastlane (and not just Bazel)

Bazel produces the `.ipa` but has no concept of App Store Connect. Fastlane's `upload_to_testflight` and `upload_to_app_store` handle authentication, upload, and submission. Only the upload lanes remain; the build step inside each lane calls Bazel.

### Why a Makefile

Bazel commands are verbose (`bazel test //CardsTests:CardsTests --ios_simulator_device="iPhone Duo" --ios_simulator_version=27.1`). The Makefile wraps these into short commands (`make test-unit`) and pins the Xcode, simulator device, and OS version in one place.

## Makefile Targets

| Command | What it does |
|---------|-------------|
| `make build` | `bazel build //Cards:Cards` |
| `make test-unit` | Run unit tests on iPhone Duo / iOS 27.1 |
| `make test-e2e` | Run UI tests on iPhone Duo / iOS 27.1 |
| `make test` | Run both unit and UI tests |
| `make sim` | Build, boot iPhone Duo, open Device Hub, install and launch the app |
| `make device-hub` | Alias for `make sim` |
| `make xcodeproj` | Regenerate `Cards.xcodeproj` from BUILD files |
| `make capture-screenshots` | Refresh en-US and en-GB iPhone/iPad App Store screenshots |
| `make validate-screenshots` | Validate the checked-in screenshot set and image dimensions |

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

## Fastlane Lanes

| Lane | Used by | Purpose |
|------|---------|---------|
| `deploy_alpha` | CI (deploy.yml) | Bazel build (arm64, opt) then upload to TestFlight |
| `release` | Manual | Bazel build then upload to App Store with auto-submit |
| `screenshots` | Manual | Upload screenshots to App Store Connect |
| `metadata` | Manual | Upload metadata to App Store Connect |

## Packages

### CardsCore

Foundation types shared across all modules.

- `Models/` — `CardItem` (SwiftData model), `BarcodeType`, `CardItemDTO`
- `Navigation/` — `NavigationRoute`, `NavigationManager` (@Observable)
- `Services/` — `PerformanceTracker` (cold/warm start timing), `Loader` (debug only)

### CardsUI

Every view in the app, with no store, camera or device access. See
"Views are detached from state" above.

- `Screens/` — `CardListView`, `CardDetailView`, `CardEditView`, `SettingsListView`
- `ViewState/` — `CardSummary`, `CardDetail`, `CardDraft`, `SettingsState`, `SampleData`
- `Actions/` — closure bundles raised by each screen
- `Environment/` — `ScreenBrightness`, `AccessibilityAnnouncer` (injected effects)
- `Components/` — `BarcodeView` (renders barcodes via RSBarcodes_Swift), `Spinner`, `ShareSheet`
- `Modifiers/` — `ConditionalModifier`, `PortraitLockedView`
- `Theme/` — `Colors` (adaptive light/dark palette)
- `Extensions/` — `UIScreen.current` (replaces deprecated `UIScreen.main`)

### CardsScanner

Camera-based barcode scanning.

- `ScannerViewController` — AVCaptureSession with metadata output
- `CameraScannerView` — SwiftUI wrapper (UIViewControllerRepresentable)

### CardsFeatures

Connectors that bind SwiftData and navigation to the `CardsUI` views. All the
impure work lives here.

- `CardListScreen.swift` — `@Query` list, reordering, deletion, navigation destinations
- `Components/CardDetailScreen.swift` — maps `CardItem` to `CardDetail`, owns the brightness preference
- `Components/CardEditScreen.swift` — owns the draft, feeds the real scanner in, commits on save
- `Components/SettingsScreen.swift` — version info, import/export, delete all, clipboard

### CardsStorybook

Debug-only story catalogue and browser. Depends on `CardsUI` only, never on
`CardsFeatures` or `CardsScanner`.

- `Story.swift` — `Story`, `StoryKnob`, `KnobValues`
- `StorybookView.swift` — sidebar, Interactive/Gallery stage, knob controls
- `DisplayOptions.swift` — colour scheme, Dynamic Type, layout direction
- `Catalogue/` — the stories themselves

## CI/CD

### CI (`ci.yml`)

Runs on every push to `main` and on pull requests. Uses `macos-26` runner.

1. Installs Bazelisk
2. Validates the checked-in screenshot set
3. Boots fixed iPhone and iPad device classes on compatible installed runtimes
4. Runs the Bazel build and Xcode unit/UI tests
5. Exports screenshot attachments and compares them with all references

### Deploy (`deploy.yml`)

Runs after CI succeeds on `main`, on version tags (`v*`), or manual dispatch.

1. Installs Bazelisk, Apple certificate, and provisioning profile from secrets
2. Sets up Ruby 3.2 and Fastlane
3. `fastlane deploy_alpha` (Bazel build + TestFlight upload)

Required GitHub secrets: `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `BUILD_PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD`, `APPLE_ID`, `ITC_TEAM_ID`, `TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`.

## Project Files

| File | Purpose |
|------|---------|
| `MODULE.bazel` | Bazel module: external dependencies (rules_apple, rules_swift, rules_xcodeproj, rules_swift_package_manager) |
| `.bazelrc` | Build settings: disk cache, local performance, simulator config for Xcode |
| `xcodeproj.bazelrc` | Overrides for Xcode builds (writable outputs to fix permission issues) |
| `.bazelversion` | Pins Bazel version (via Bazelisk) |
| `Package.swift` | Root SPM manifest declaring local package dependencies; consumed by rules_swift_package_manager |
| `Package.resolved` | Pinned versions of external SPM dependencies |
| `BUILD` (root) | `xcodeproj` target for generating the Xcode project |
| `Cards/BUILD` | App target: `swift_library` + `ios_application` |
| `Info.plist` | App metadata template (version substituted by Bazel) |
| `Gemfile` | Ruby dependency: Fastlane |
| `.swiftlint.yml` | SwiftLint configuration |

## Development

### Opening in Xcode

```bash
make xcodeproj
open Cards.xcodeproj
```

The Xcode project is generated by Bazel and not tracked in git. Regenerate it after changing any BUILD file or adding/removing source files.

### Adding a source file

1. Create the file in the appropriate `Packages/*/Sources/` directory
2. No BUILD file changes needed (glob patterns pick up new files)
3. Run `make xcodeproj` to update the Xcode project

### Adding an external dependency

1. Add to the relevant `Packages/*/Package.swift`
2. Add to the root `Package.swift`
3. Run `swift package resolve` then `bazel mod tidy`
4. Add the Bazel dep label to the package's `BUILD` file
