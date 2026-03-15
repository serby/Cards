# Card Barcodes

A modern iOS application for managing barcode cards on your iPhone. Store loyalty cards, membership cards, and any barcode-based cards for quick access without carrying physical cards.

## Features

- **Scan barcodes** - Use camera to capture barcode values automatically
- **Multiple barcode formats** - Supports QR, EAN-8, EAN-13, Code128, Code39, Code93, UPC-E, Aztec, PDF417
- **Custom names** - Label cards with memorable names
- **Drag to reorder** - Organize cards in your preferred order
- **Swipe to delete** - Remove cards with a swipe gesture
- **Full brightness** - Automatically increases screen brightness for better scanning
- **Deep linking** - Open specific cards via `cards://` URLs
- **SwiftUI** - Modern, native iOS interface with dark mode support
- **SwiftData** - Modern data persistence with automatic saving

## Installation & Setup

### Prerequisites
- macOS with Xcode 26 or later
- iOS 18.0+ deployment target
- Apple Developer account (for device testing)
- Ruby 3.2+ via asdf (see `.tool-versions`)
- [Bazelisk](https://github.com/bazelbuild/bazelisk) (`brew install bazelisk`)

### Clone and Build
```bash
git clone https://github.com/serby/Cards.git
cd Cards

# Generate the Xcode project from Bazel
bazel run //:xcodeproj

# Open in Xcode
open Cards.xcodeproj
```

### Dependencies
Dependencies are managed via Swift Package Manager and built by Bazel:
- **RSBarcodes_Swift** - Barcode generation

## Build System

This project uses [Bazel](https://bazel.build/) as its build system, with [rules_xcodeproj](https://github.com/MobileNativeFoundation/rules_xcodeproj) generating an Xcode project for IDE use.

### Command-line builds
```bash
# Build the app
bazel build //Cards:Cards

# Run tests
bazel test //CardsTests:CardsTests

# Regenerate Xcode project (after changing BUILD files)
bazel run //:xcodeproj
```

### Xcode workflow
1. Run `bazel run //:xcodeproj` to generate the project
2. Open `Cards.xcodeproj` in Xcode
3. Build and run as normal (Xcode delegates to Bazel)

### Key Bazel files
- `.bazelversion` - Pins Bazel version (managed by Bazelisk)
- `MODULE.bazel` - External dependencies
- `.bazelrc` - Build settings (disk cache, local performance)
- `BUILD` - Root build file with xcodeproj target
- `Cards/BUILD` - App target (swift_library + ios_application)
- `CardsTests/BUILD` - Unit test target
- `CardsUITests/BUILD` - UI test target
- `Package.swift` / `Package.resolved` - SPM dependency declarations (consumed by rules_swift_package_manager)

## Build & Test

### Using Bazel (recommended)
```bash
# Build the app
bazel build //Cards:Cards

# Run unit tests
bazel test //CardsTests:CardsTests

# Run UI tests
bazel test //CardsUITests:CardsUITests
```

### Using Fastlane
```bash
# Install Ruby via asdf
asdf install

# Install dependencies
bundle install

# Build and run on simulator
bundle exec fastlane sim

# Deploy to TestFlight
bundle exec fastlane deploy_alpha

# Deploy to App Store
bundle exec fastlane release
```

### Using Xcode
1. Run `bazel run //:xcodeproj` to generate the project
2. Open `Cards.xcodeproj`
3. Select the Cards scheme
4. Choose a simulator
5. Press Cmd+B to build or Cmd+U to test

## CI/CD Pipeline

### GitHub Actions Workflows

#### CI Workflow (`.github/workflows/ci.yml`)
Runs on every push to `main` and pull requests:
- Build and test on iPhone simulator (macOS 26, Xcode 26)
- Simulator device and iOS version resolved dynamically
- Upload test results as artifacts

#### Deploy Workflow (`.github/workflows/deploy.yml`)
Automated TestFlight deployment:
- Triggers on successful CI, manual dispatch, or version tags (`v*`)
- Installs certificates and provisioning profiles from secrets
- Deploys via `fastlane deploy_alpha`

**Required Secrets**: `APPLE_ID`, `ITC_TEAM_ID`, `TEAM_ID`, `APP_STORE_CONNECT_API_KEY`, `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `BUILD_PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD`

### Fastlane Lanes
- `fastlane sim` - Build and run on simulator
- `fastlane deploy_alpha` - Deploy to TestFlight
- `fastlane release` - Deploy to App Store

---

## Project Architecture

### Directory Structure
```
Cards/
├── App/
│   └── CardsApp.swift                    # Main app entry point with TabView
├── Core/
│   ├── Models/
│   │   ├── BarcodeType.swift            # Barcode type enum and AVFoundation mapper
│   │   └── CardItem.swift               # SwiftData model for cards
│   ├── Navigation/
│   │   ├── NavigationManager.swift      # Centralized navigation state
│   │   └── NavigationRoute.swift        # Type-safe route definitions
│   ├── Services/
│   │   └── PerformanceTracker.swift     # Cold/warm start tracking
│   └── Theme/
│       └── Colors.swift                 # Adaptive color theme (light/dark)
├── Features/
│   ├── CardDetail/Views/CardItemView.swift       # Card display with brightness boost
│   ├── CardEdit/Views/EditCardItemView.swift     # Card editing form
│   ├── CardList/Views/CardsView.swift            # Main card list
│   ├── Scanner/Views/
│   │   ├── CameraScannerView.swift               # SwiftUI camera wrapper
│   │   └── ScannerViewControllerDelegate.swift   # UIKit AVCaptureSession
│   └── Settings/Views/SettingsView.swift         # Settings with import/export
└── UI/
    ├── Components/
    │   ├── BarcodeView.swift            # RSBarcodes rendering
    │   └── Spinner.swift                # Loading spinner with grace period
    └── Modifiers/
        ├── PortraitLockedView.swift     # Portrait orientation lock
        └── ConditionalModifier.swift    # Conditional view modifiers
```

### Key Components

#### Navigation System
- **NavigationManager** - `@ObservableObject` managing `NavigationPath`
- **NavigationRoute** - Enum with cases: `.cards`, `.card(code)`, `.editCard(code)`, `.newCard`, `.camera`
- **Deep Linking** - URL scheme `cards://` with path parsing

#### Data Layer
- **CardItem** - SwiftData `@Model` with `code`, `name`, `order`, `type`, `timestamp`
- **BarcodeType** - Enum mapping app types to AVFoundation `AVMetadataObject.ObjectType`

#### Camera Integration
- **ScannerViewControllerDelegate** - UIKit `AVCaptureSession` with metadata output
- **CameraScannerView** - `UIViewControllerRepresentable` bridge with proper cleanup via `dismantleUIViewController`

#### Theme System
- **Colors.swift** - Adaptive colors using `UIColor.systemBackground`, `UIColor.label`
- **Pink accent** - Brand color consistent across light/dark modes

### Navigation Paths
| Route | Path | Description |
|-------|------|-------------|
| `.cards` | `/cards` | Main card list |
| `.card(code)` | `/cards/card/{code}` | Card detail view |
| `.editCard(code)` | `/cards/card/{code}/edit` | Edit card |
| `.newCard` | `/cards/new` | New card form |
| `.camera` | `/cards/new/camera` | Camera scanner |

---

## Development Guidelines

### Coding Style
- Use `async/await` and `Task` for concurrency
- Prefer SwiftUI over UIKit
- Use `#available` for iOS version checks (not `ProcessInfo`)
- Follow Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`

### Testing
- **NavigationTests** - Route parsing and navigation flows
- **Unit tests** - Component logic
- **UI tests** - End-to-end scenarios with `-uiTesting` flag

### Adding New Routes
1. Add case to `NavigationRoute` enum
2. Update `from(path:)` parser
3. Update `NavigationManager.navigate(to:)`
4. Add `navigationDestination` in `CardsView`

---

## License

[Add your license here]

## Contact

Created by Paul Serby - [GitHub](https://github.com/serby)
