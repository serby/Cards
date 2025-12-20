# Cards App

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

### Clone and Build
```bash
git clone https://github.com/serby/Cards.git
cd Cards
open Cards.xcodeproj
```

### Dependencies
Dependencies are managed via Swift Package Manager:
- **RSBarcodes_Swift** - Barcode generation
- **SwiftLintPlugins** - Code linting

## Build & Test

### Using Fastlane
```bash
# Install dependencies
brew install fastlane
bundle install

# Build for testing
fastlane build

# Run tests
fastlane test

# Deploy to TestFlight
fastlane beta

# Deploy to App Store
fastlane release
```

### Using Xcode
1. Open `Cards.xcodeproj`
2. Select the Cards scheme
3. Choose a simulator or device
4. Press Cmd+B to build or Cmd+U to test

## CI/CD Pipeline

### GitHub Actions Workflows

#### CI Workflow (`.github/workflows/ci.yml`)
Runs on every push to `main` and pull requests:

- **Triggers**: Push to main, pull requests (ignores docs, fastlane, and config files)
- **Runner**: macOS 26 with Xcode 26
- **Steps**:
  1. Checkout code
  2. Show Xcode version
  3. List available simulators
  4. Build and test on iPhone 17 Pro Max simulator
  5. Upload test results as artifacts

```yaml
# Runs clean build and test with:
xcodebuild -scheme Cards \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.1,arch=arm64' \
  -skipPackagePluginValidation \
  clean build test -quiet
```

#### Deploy Workflow (`.github/workflows/deploy.yml`)
Automated TestFlight deployment:

- **Triggers**: 
  - Manual dispatch
  - Successful CI workflow completion on main
  - Version tags (`v*`)
- **Runner**: macOS 26
- **Steps**:
  1. Checkout code
  2. Install Fastlane via Homebrew
  3. Setup Ruby 3.2 with bundler cache
  4. Deploy to TestFlight using `fastlane beta`

**Required Secrets**:
- `APPLE_ID` - Apple Developer account email
- `ITC_TEAM_ID` - App Store Connect team ID
- `TEAM_ID` - Apple Developer team ID
- `APP_STORE_CONNECT_API_KEY` - App-specific password

### Fastlane Configuration

#### Available Lanes
- `fastlane build` - Build for testing (Debug, no codesigning)
- `fastlane test` - Run tests on iPhone 16 simulator
- `fastlane beta` - Build and deploy to TestFlight
- `fastlane release` - Build and deploy to App Store (manual review)

#### Beta Deployment Process
1. Increment build number automatically
2. Build with Release configuration
3. Export for App Store distribution
4. Upload to TestFlight
5. Skip waiting for build processing

#### Release Deployment Process
1. Increment build number automatically
2. Build with Release configuration
3. Upload to App Store Connect
4. Requires manual review submission

### Deployment Flow

```
Code Push → CI Tests → Manual/Auto Trigger → TestFlight → App Store
     ↓           ↓              ↓              ↓           ↓
   GitHub    Build & Test   Deploy Workflow  Beta Lane  Release Lane
   Actions   on Simulator   (macOS runner)   (Fastlane) (Fastlane)
```

## Architecture

### Navigation System
- **NavigationStack-based routing** with path-based deep linking
- **NavigationManager** - Centralized navigation state management
- **NavigationRoute enum** - Type-safe route definitions
- **URL scheme** - `cards://` for deep linking

### Navigation Paths
- `/cards` - Main card list
- `/cards/card/{code}` - Card detail view
- `/cards/card/{code}/edit` - Edit existing card
- `/cards/new` - Create new card
- `/cards/new/camera` - Camera scanner for new card

### Key Technologies
- **SwiftUI** - Main UI framework with NavigationStack
- **SwiftData** - Persistence framework for card storage
- **AVFoundation** - Camera access and barcode scanning
- **RSBarcodes_Swift** - Barcode generation library

### Project Structure
```
Cards/
├── App/
│   └── CardsApp.swift                    # Main app entry point
├── Core/
│   ├── Models/
│   │   ├── BarcodeType.swift            # Barcode type enum and mapper
│   │   └── CardItem.swift               # SwiftData model for cards
│   ├── Navigation/
│   │   ├── NavigationManager.swift      # Navigation state management
│   │   └── NavigationRoute.swift        # Route definitions
│   └── Services/
│       └── PerformanceTracker.swift     # App performance metrics
├── Features/
│   ├── CardDetail/
│   │   └── Views/
│   │       └── CardItemView.swift       # Card detail display
│   ├── CardEdit/
│   │   └── Views/
│   │       └── EditCardItemView.swift   # Card editing form
│   ├── CardList/
│   │   └── Views/
│   │       └── CardsView.swift          # Main card list view
│   ├── Scanner/
│   │   └── Views/
│   │       ├── CameraScannerView.swift  # SwiftUI camera wrapper
│   │       └── ScannerViewControllerDelegate.swift  # UIKit camera controller
│   └── Settings/
│       └── Views/
│           └── SettingsView.swift       # Settings screen
└── UI/
    ├── Components/
    │   ├── BarcodeView.swift            # Barcode rendering
    │   └── Spinner.swift                # Loading spinner
    └── Modifiers/
        ├── PortraitLockedView.swift     # Portrait orientation lock
        └── ConditionalModifier.swift    # Conditional view modifiers
```

## Development

### Contributing
This project welcomes contributions! Please:
- Report bugs via GitHub Issues
- Submit feature requests
- Create pull requests with improvements
- Follow the coding style guide below

### Adding New Features
1. Create feature branch from `main`
2. Implement feature following coding style guide
3. Write tests for new functionality
4. Update documentation
5. Submit pull request

### Coding Style Guide

#### Modern Swift Practices
- ✅ Use `async/await` for asynchronous operations
- ✅ Use `Task` for background work
- ✅ Use `@State`, `@Binding`, `@ObservedObject` appropriately
- ✅ Prefer SwiftUI over UIKit
- ✅ Minimal, focused implementations

#### Git Commit Style
Follow [Conventional Commits](https://www.conventionalcommits.org/):
```
feat: add user authentication
fix(scanner): handle empty barcode values
docs: update README with CI/CD details
```

### Testing
- **NavigationTests** - 21 comprehensive tests covering route parsing and navigation flows
- **Unit tests** - Individual component logic
- **Integration tests** - Complete user journey validation
- **UI tests** - End-to-end user scenarios

## License

[Add your license here]

## Contact

Created by Paul Serby - [GitHub](https://github.com/serby)
