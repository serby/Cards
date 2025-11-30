# Cards App

A SwiftUI-based iOS application for barcode card management with camera scanning and deep linking capabilities.

## Coding Style Guide

### Modern Swift Practices

#### Concurrency
- ✅ Use `async/await` and `Task` for asynchronous operations
- ✅ Use `Task.sleep(for:)` for delays
- ❌ Avoid `DispatchQueue.async` and `DispatchQueue.asyncAfter`

```swift
// ✅ Preferred
.task {
    try? await Task.sleep(for: .seconds(0.6))
    isReady = true
}

// ❌ Avoid
.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        isReady = true
    }
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
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `perf`: Performance improvements

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

## Architecture

### Navigation System
- **NavigationStack-based routing** with path-based deep linking
- **NavigationManager**: Centralized navigation state management
- **NavigationRoute enum**: Type-safe route definitions
- **URL scheme**: `cards://` for deep linking

### Navigation Paths
- `/cards` - Main card list (ContentView)
- `/cards/card/{code}` - Card detail view (CardItemView)
- `/cards/card/{code}/edit` - Edit existing card (EditCardItemView)
- `/cards/new` - Create new card (EditCardItemView)
- `/cards/new/camera` - Camera scanner for new card

### Key Technologies
- **SwiftUI**: Main UI framework with NavigationStack
- **SwiftData**: Persistence framework for card storage
- **AVFoundation**: Camera access and barcode scanning
- **RSBarcodes_Swift**: Barcode generation library

## Project Structure

### Navigation Components
```
Cards/Navigation/
├── NavigationRoute.swift      # Route enum with path parsing
└── NavigationManager.swift    # Centralized navigation state
```

### Core Views
```
Cards/
├── ContentView.swift          # Main list with NavigationStack
├── CardItemView.swift         # Card detail with barcode display
├── EditCardItemView.swift     # Card creation/editing form
├── CameraScannerView.swift    # Camera scanning interface
└── BarcodeView.swift          # Barcode rendering component
```

### Models & Data
```
Cards/Models/
├── CardItem.swift             # SwiftData model for cards
└── BarcodeType.swift          # Barcode format definitions
```

## Implementation Details

### NavigationManager Usage
```swift
// Navigate to specific card
NavigationManager.shared.navigate(to: .card("123456"))

// Handle deep links
NavigationManager.shared.handleDeepLink(url)

// Current route access
@ObservedObject var navigationManager = NavigationManager.shared
```

### Deep Link Integration
```swift
// CardsApp.swift - Entry point
private func handleDeepLink(_ url: URL) {
    NavigationManager.shared.handleDeepLink(url)
}

// URL scheme registration in Info.plist
// cards://card/123456 → NavigationRoute.card("123456")
```

### SwiftData Configuration
```swift
// CardsApp.swift
.modelContainer(for: CardItem.self)

// CardItem model with ordering
@Model
final class CardItem {
    var timestamp: Date
    var code: String
    var name: String
    var order: Int
    var type: String
}
```

### Testing Strategy
- **NavigationTests.swift**: 21 comprehensive tests covering route parsing, navigation flows, and deep linking
- **Unit tests**: Individual component logic
- **Integration tests**: Complete user journey validation
- **Manual testing**: End-to-end user scenarios

## Development Commands

### Build and Test
```bash
# Build
make build

# Test
make test

# Using Fastlane
fastlane build
fastlane test
```

### Deployment
```bash
# Deploy to TestFlight
fastlane beta

# Deploy to App Store
fastlane release
```

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for full deployment pipeline documentation.

## Development Workflow

### Adding New Routes
1. Update `NavigationRoute` enum with new case
2. Add path parsing logic in `from(path:)` method
3. Update `NavigationManager.navigate(to:)` handling
4. Add destination view in ContentView's `navigationDestination`
5. Write tests for new route and navigation flow

### Testing New Features
1. Write unit tests for individual components
2. Create integration tests for complete flows
3. Add manual test scenarios
4. Verify all entry points are connected
5. Check for old pattern usage with `grep -r "pattern" .`

## Common Patterns

### Navigation Flow Testing
```swift
func testNavigationFlow() {
    let manager = NavigationManager()
    manager.navigate(to: .card("123"))
    XCTAssertEqual(manager.currentRoute, .card("123"))
    XCTAssertEqual(manager.path.count, 1)
}
```

### Deep Link Handling
```swift
func testDeepLinkHandling() {
    let url = URL(string: "cards://card/123")!
    let manager = NavigationManager()
    manager.handleDeepLink(url)
    XCTAssertEqual(manager.currentRoute, .card("123"))
}
```

### Route Parsing
```swift
func testRouteParsing() {
    let route = NavigationRoute.from(path: "/cards/card/123")
    XCTAssertEqual(route, .card("123"))
}
```
