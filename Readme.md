# Cards App

A modern iOS application for managing barcode cards on your iPhone. Store loyalty cards, membership cards, and any barcode-based cards for quick access without carrying physical cards.

## What It Does

Cards is a SwiftUI-based barcode card manager that lets you:
- Scan barcodes using your camera
- Store cards with custom names
- Display barcodes for scanning at stores
- Organize cards with drag-and-drop reordering
- Access cards quickly with deep linking

## Features

### Card Management
- **Scan barcodes** - Use camera to capture barcode values automatically
- **Multiple barcode formats** - Supports QR, EAN-8, EAN-13, Code128, Code39, Code93, UPC-E, Aztec, PDF417
- **Custom names** - Label cards with memorable names
- **Drag to reorder** - Organize cards in your preferred order
- **Swipe to delete** - Remove cards with a swipe gesture
- **Search** - Quickly find cards (when enabled)

### Barcode Display
- **Full brightness** - Automatically increases screen brightness for better scanning
- **Large display** - Shows barcode prominently for easy scanning
- **Multiple formats** - Renders barcodes in the correct format for each card

### User Interface
- **SwiftUI** - Modern, native iOS interface
- **Dark mode** - Full support for light and dark themes
- **Accessibility** - VoiceOver support throughout
- **Haptic feedback** - Tactile responses for interactions
- **Hide toolbar on scroll** - Maximizes screen space when browsing

### Navigation
- **Deep linking** - Open specific cards via `cards://` URLs
- **Tab-based** - Cards and Settings tabs
- **Type-safe routing** - NavigationStack with route definitions

### Data & Persistence
- **SwiftData** - Modern data persistence
- **Automatic saving** - Changes saved immediately
- **Order preservation** - Card order maintained across launches

### Performance
- **Launch tracking** - Monitors cold and warm start times
- **Optimized rendering** - Efficient barcode generation
- **Background camera** - Camera starts on background thread

## Contributing

This project is open source and welcomes contributions! Feel free to:
- Report bugs via GitHub Issues
- Submit feature requests
- Create pull requests with improvements
- Suggest enhancements

See the [Development Workflow](#development-workflow) section for guidelines on contributing code.

## Installation & Setup

### Prerequisites
- macOS with Xcode 26 or later
- iOS 18.0+ deployment target
- Apple Developer account (for device testing)

### Clone and Build
```bash
# Clone the repository
git clone https://github.com/serby/Cards.git
cd Cards

# Open in Xcode
open Cards.xcodeproj

# Or build from command line
make build
```

### Dependencies
Dependencies are managed via Swift Package Manager and will be resolved automatically:
- **RSBarcodes_Swift** - Barcode generation
- **SwiftLintPlugins** - Code linting

## Build & Test

### Using Make
```bash
# Build
make build

# Run tests
make test

# CI build (clean + build + test)
make ci
```

### Using Fastlane
```bash
# Install Fastlane
brew install fastlane

# Build
fastlane build

# Run tests
fastlane test
```

### Using Xcode
1. Open `Cards.xcodeproj`
2. Select the Cards scheme
3. Choose a simulator or device
4. Press Cmd+B to build or Cmd+U to test

## Deployment

### TestFlight
```bash
# Deploy to TestFlight
fastlane beta
```

### App Store
```bash
# Deploy to App Store
fastlane release
```

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for complete CI/CD pipeline documentation including:
- GitHub Actions workflows
- Certificate management
- Secrets configuration
- Automated deployment

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

## Development Workflow

### Adding New Features
1. Create feature branch from `main`
2. Implement feature following coding style guide
3. Write tests for new functionality
4. Update documentation
5. Submit pull request

### Adding New Routes
1. Update `NavigationRoute` enum with new case
2. Add path parsing logic in `from(path:)` method
3. Update `NavigationManager.navigate(to:)` handling
4. Add destination view in `navigationDestination`
5. Write tests for new route and navigation flow

### Testing New Features
1. Write unit tests for individual components
2. Create integration tests for complete flows
3. Add manual test scenarios
4. Verify all entry points are connected
5. Run full test suite before submitting PR

## Coding Style Guide

### Modern Swift Practices

#### Concurrency
- ✅ Use `async/await` for truly asynchronous operations
- ✅ Use `Task` for background work (even with synchronous code)
- ✅ Use `Task.sleep(for:)` for delays
- ❌ Avoid `DispatchQueue.async` and `DispatchQueue.asyncAfter` (use `Task` instead)
- ⚠️ Don't use `await` on non-async methods

```swift
// ✅ Preferred - async/await for delays
.task {
    try? await Task.sleep(for: .seconds(0.6))
    isReady = true
}

// ✅ Preferred - Task for background work (no await needed)
Task {
    captureSession?.startRunning() // Synchronous but blocking
}

// ❌ Avoid - DispatchQueue
.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        isReady = true
    }
}

// ❌ Wrong - await on non-async method
Task {
    await captureSession?.startRunning() // startRunning() is not async!
}
```

#### State Management
- ✅ Use `@State`, `@Binding`, `@ObservedObject`, `@StateObject` appropriately
- ✅ Use `@FocusState` for keyboard focus management
- ✅ Batch state updates with `objectWillChange.send()` to prevent multiple updates per frame

```swift
// ✅ Batch updates
func navigate(to route: NavigationRoute) {
    objectWillChange.send()
    currentRoute = route
    navigationPath = NavigationPath()
}
```

#### SwiftUI
- ✅ Prefer SwiftUI over UIKit
- ✅ Use `.task` modifier for async work in views
- ✅ Use modern view modifiers and APIs
- ❌ Only use UIKit when absolutely necessary (e.g., AVCaptureSession)

#### Code Style
- ✅ Minimal, focused implementations
- ✅ Clear, descriptive naming
- ✅ Use Swift's modern features (property wrappers, result builders)
- ✅ Avoid verbose or unnecessary code

### Git Commit Style

Follow [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

#### Types
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code refactoring
- `docs` - Documentation changes
- `style` - Code style changes (formatting)
- `test` - Adding or updating tests
- `chore` - Maintenance tasks
- `perf` - Performance improvements

#### Examples
```bash
# Simple feature
feat: add user authentication

# Bug fix with scope
fix(scanner): handle empty barcode values

# Breaking change
feat!: update navigation to use NavigationStack

# With body
feat: add scanner integration

- Integrate camera scanner with new card form
- Add auto-focus to name field
- Batch navigation state updates
```

## Testing

### Test Coverage
- **NavigationTests** - 21 comprehensive tests covering route parsing, navigation flows, and deep linking
- **Unit tests** - Individual component logic
- **Integration tests** - Complete user journey validation
- **UI tests** - End-to-end user scenarios
- **Performance tests** - Launch time baselines

### Running Tests
```bash
# All tests
make test

# Specific test
xcodebuild test -scheme Cards -destination 'platform=iOS Simulator,name=iPhone 16'

# With Fastlane
fastlane test
```

## License

[Add your license here]

## Contact

Created by Paul Serby - [GitHub](https://github.com/serby)
