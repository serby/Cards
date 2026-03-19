# Cards

A barcode wallet for iOS. Store loyalty cards, scan barcodes with the camera, and display them at full brightness for easy scanning at the till.

Built with SwiftUI, SwiftData, and structured as an SPM monorepo with Bazel.

## Quick Start

```bash
# Build
make build

# Run unit tests
make test-unit

# Build and launch in simulator
make sim

# Generate Xcode project (run after changing BUILD files)
make xcodeproj
```

Requires Xcode 26+, [Bazelisk](https://github.com/bazelbuild/bazelisk), and iOS 18.0+ deployment target.

## Architecture

Four SPM packages under `Packages/`, each with its own `Package.swift` and Bazel `BUILD` file:

```
Packages/
  CardsCore/         Models, navigation, services (no UI dependencies)
  CardsUI/           Reusable UI components, theme, barcode rendering
  CardsScanner/      Camera barcode scanning (AVFoundation)
  CardsFeatures/     Feature views (card list, detail, edit, settings)
```

Dependency graph:

```
CardsFeatures → CardsCore, CardsUI, CardsScanner
CardsUI       → CardsCore, RSBarcodes_Swift
CardsScanner  → CardsCore
CardsCore     → (Foundation, SwiftData, SwiftUI, AVFoundation)
```

The app target lives in `Cards/App/CardsApp.swift` and imports `CardsCore` + `CardsFeatures`.

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

Bazel commands are verbose (`bazel test //CardsTests:CardsTests --ios_simulator_device="iPhone 17" --ios_simulator_version=26.3`). The Makefile wraps these into short commands (`make test-unit`) and pins the simulator device and OS version in one place.

## Makefile Targets

| Command | What it does |
|---------|-------------|
| `make build` | `bazel build //Cards:Cards` |
| `make test-unit` | Run unit tests on iPhone 17 / iOS 26.3 |
| `make test-e2e` | Run UI tests on iPhone 17 / iOS 26.3 |
| `make test` | Run both unit and UI tests |
| `make sim` | Build, boot simulator, install and launch the app |
| `make xcodeproj` | Regenerate `Cards.xcodeproj` from BUILD files |

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

Reusable UI components with no feature-level logic.

- `Components/` — `BarcodeView` (renders barcodes via RSBarcodes_Swift), `Spinner`
- `Modifiers/` — `ConditionalModifier`, `PortraitLockedView`
- `Theme/` — `Colors` (adaptive light/dark palette)
- `Extensions/` — `UIScreen.current` (replaces deprecated `UIScreen.main`)

### CardsScanner

Camera-based barcode scanning.

- `ScannerViewController` — AVCaptureSession with metadata output
- `CameraScannerView` — SwiftUI wrapper (UIViewControllerRepresentable)

### CardsFeatures

Feature views that compose the app's screens.

- `CardsView.swift` — Card list with navigation, reordering, deletion
- `Components/CardItemView.swift` — Card detail with brightness boost
- `Components/EditCardItemView.swift` — Add/edit card form
- `Components/SettingsView.swift` — App settings, import/export, delete all

## CI/CD

### CI (`ci.yml`)

Runs on every push to `main` and on pull requests. Uses `macos-26` runner.

1. Installs Bazelisk
2. Dynamically resolves an available iPhone simulator
3. `bazel build //Cards:Cards`
4. `bazel test //CardsTests:CardsTests`

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
