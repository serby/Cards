# Cards Project - Comprehensive Context

## Project Overview
A SwiftUI barcode card management app that allows users to store, scan, and display various types of barcodes (QR codes, EAN, Code128, etc.) for quick access to loyalty cards, membership cards, and similar items.

## Directory Structure

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
│       ├── Loader.swift                 # Debug loading indicator
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
│   └── Scanner/
│       └── Views/
│           ├── CameraScannerView.swift  # SwiftUI camera wrapper
│           └── ScannerViewControllerDelegate.swift  # UIKit camera controller
├── UI/
│   ├── Components/
│   │   ├── BarcodeView.swift            # Barcode rendering
│   │   └── Spinner.swift                # Loading spinner
│   └── Modifiers/
│       ├── PortraitLockedView.swift     # Portrait orientation lock
│       └── View+Extensions.swift        # View helper extensions
├── Assets.xcassets/
└── Cards.entitlements
```

---

## File Details

### App Layer

#### **CardsApp.swift**
**Purpose**: Main app entry point with TabView navigation and lifecycle management

**Key Properties**:
- `navigationManager: NavigationManager` - Shared navigation state
- `performanceTracker: PerformanceTracker` - App performance monitoring
- `sharedModelContainer: ModelContainer` - SwiftData persistence

**Key Functions**:
- `init()` - Sets up model container with in-memory option for testing
- `tabView` - Creates TabView with Cards and Settings tabs
- `.onChange(of: scenePhase)` - Tracks app lifecycle transitions

**Features**:
- Tab-based navigation (Cards, Settings)
- Deep link handling via `onOpenURL`
- Performance tracking for cold/warm starts
- Resets navigation to root when returning to Cards tab from camera view

---

### Core Layer

#### **Models/BarcodeType.swift**
**Purpose**: Defines supported barcode types and maps between app and AVFoundation types

**Key Types**:
- `BarcodeType` enum - 9 barcode formats (QR, EAN-8, EAN-13, Code128, Code39, Code93, UPC-E, Aztec, PDF417)
- `BarcodeMapper` struct - Bidirectional mapping utilities

**Key Functions**:
- `mapBarcodeTypeToMetadataObjectType()` - App type → AVFoundation type
- `mapMetadataObjectTypeToBarcodeType()` - AVFoundation type → App type

**Conformances**: `Codable`, `CaseIterable`, `Hashable`

---

#### **Models/CardItem.swift**
**Purpose**: SwiftData model representing a stored card

**Key Properties**:
- `timestamp: Date` - Creation date
- `code: String` - Barcode value
- `name: String` - User-friendly card name
- `order: Int` - Display order in list
- `type: String` - Barcode type (stored as raw value)

**Key Functions**:
- `getBarcodeType()` - Converts stored string to BarcodeType enum

**Conformances**: `@Model` (SwiftData), `Identifiable`

---

#### **Navigation/NavigationManager.swift**
**Purpose**: Centralized navigation state management using NavigationPath

**Key Properties**:
- `navigationPath: NavigationPath` - SwiftUI navigation stack
- `currentRoute: NavigationRoute` - Current active route

**Key Functions**:
- `navigate(to:)` - Programmatic navigation with route-specific path building
- `resetToRoot()` - Clears navigation stack (only if on camera view)
- `handleDeepLink()` - Processes deep link URLs (scheme: `cards://`)

**Navigation Patterns**:
- `.cards` - Root list view (clears stack)
- `.card(code)` - Detail view (single level)
- `.editCard(code)` - Edit view (card → edit)
- `.newCard` - New card form (single level)
- `.camera` - Scanner view (newCard → camera)

---

#### **Navigation/NavigationRoute.swift**
**Purpose**: Type-safe route definitions with deep link support

**Key Cases**:
- `.cards` - Card list
- `.card(String)` - Card detail with code
- `.editCard(String)` - Edit card with code
- `.newCard` - New card form
- `.camera` - Camera scanner

**Key Functions**:
- `id` - Unique identifier for each route
- `path` - URL path representation
- `from(path:)` - Parses URL path to route

**Conformances**: `Hashable`, `Identifiable`

---

#### **Services/PerformanceTracker.swift**
**Purpose**: Measures app launch and transition performance

**Key Properties**:
- `appLaunchTime: Date` - Process start time
- `foregroundTime: Date?` - Last foreground transition time

**Key Functions**:
- `recordAppLaunch()` - Logs cold start time in milliseconds
- `recordWarmStart()` - Logs warm start time from foreground
- `recordBackgroundTransition()` - Marks background state
- `recordForegroundTransition()` - Starts warm start timer

**Protocol**: `PerformanceTracking`

---

#### **Services/Loader.swift** (DEBUG only)
**Purpose**: Debug loading indicator with OSLog signposts

**Key Properties**:
- `isLoading: Bool` - Loading state
- `signpostLog: OSLog` - Performance logging

**Key Functions**:
- `load()` - Shows loader for 3 seconds with timing logs

**Annotations**: `@MainActor`, `@Observable`

---

### Features Layer

#### **CardDetail/Views/CardItemView.swift**
**Purpose**: Displays card details with barcode and brightness control

**Key Properties**:
- `item: CardItem` - Card to display
- `navigationManager: NavigationManager` - Navigation control
- `originalBrightness: CGFloat` - Saved screen brightness

**Key Functions**:
- `fadeBrightness(to:duration:)` - Smooth brightness animation
- `.onAppear` - Increases brightness to 1.0 for barcode scanning
- `.onDisappear` - Restores original brightness

**UI Elements**:
- Card name (title)
- BarcodeView (rendered barcode)
- Code text (large)
- Timestamp (secondary)
- Edit button (toolbar)

**Accessibility**: Full VoiceOver support with labels and hints

---

#### **CardEdit/Views/EditCardItemView.swift**
**Purpose**: Form for creating/editing cards

**Key Properties**:
- `cardItem: CardItem` - Card being edited
- `tempName: String` - Temporary name state
- `tempCode: String` - Temporary code state
- `selectedType: String` - Selected barcode type
- `onSave: ((CardItem) -> Void)?` - Save callback

**Key Functions**:
- Save button action - Updates card and navigates or calls callback

**UI Elements**:
- Name TextField
- Code TextField
- Barcode Type Picker (menu style)
- Save button (toolbar)

**Accessibility**: Full form accessibility with identifiers

---

#### **CardList/Views/CardsView.swift**
**Purpose**: Main card list with add/scan/edit/delete functionality

**Key Components**:
- `CardRow` - Individual card row with haptic feedback
- `CardListView` - Main list container

**Key Properties**:
- `cardItems: [CardItem]` - SwiftData query sorted by order
- `navigationManager: NavigationManager` - Navigation control
- `scannedCode: String?` - Scanned barcode result
- `barcodeType: BarcodeType?` - Scanned barcode type

**Key Functions**:
- `deleteItems(offsets:)` - Swipe to delete with reordering
- `moveItems(from:to:)` - Drag to reorder cards
- `destinationView(for:)` - Route-based view builder
- `findCard(by:)` - Lookup card by code

**UI Elements**:
- List with custom rows
- Add button (toolbar)
- Scan button (toolbar)
- NavigationDestination for routing

**Navigation**: Handles all route destinations with proper view hierarchy

---

#### **Scanner/Views/CameraScannerView.swift**
**Purpose**: SwiftUI wrapper for UIKit camera scanner

**Key Properties**:
- `scannedCode: Binding<String?>` - Scanned result binding
- `barcodeType: Binding<BarcodeType?>` - Detected type binding

**Key Functions**:
- `makeUIViewController()` - Creates ScannerViewController
- `updateUIViewController()` - No-op (stateless)
- `dismantleUIViewController()` - Properly cleans up camera session
- `makeCoordinator()` - Creates delegate coordinator

**Coordinator**: Bridges UIKit delegate to SwiftUI bindings

**Cleanup**: Stops camera session and removes preview layer on dismissal

---

#### **Scanner/Views/ScannerViewControllerDelegate.swift**
**Purpose**: UIKit camera controller with AVFoundation

**Key Properties**:
- `captureSession: AVCaptureSession?` - Camera session
- `previewLayer: AVCaptureVideoPreviewLayer?` - Camera preview
- `delegate: ScannerViewControllerDelegate?` - Scan result delegate

**Key Functions**:
- `viewDidLoad()` - Sets up camera input and metadata output
- `viewDidAppear()` - Starts camera session on background queue
- `viewWillDisappear()` - Stops camera session
- `metadataOutput()` - Handles detected barcodes

**Supported Formats**: QR, EAN-8, EAN-13, PDF417, Code128, Code39, Code93, UPC-E, Aztec

**Features**:
- Vibration feedback on successful scan
- Error sound on invalid scan
- Auto-dismiss after scan
- Portrait-only orientation

---

### UI Layer

#### **Components/BarcodeView.swift**
**Purpose**: Renders barcodes using RSBarcodes_Swift library

**Key Properties**:
- `barcodeString: String` - Code to encode
- `barcodeType: BarcodeType` - Barcode format

**Key Functions**:
- `generateBarcode(from:type:)` - Creates UIImage barcode at 400pt width

**Dependencies**: RSBarcodes_Swift library

**Accessibility**: Describes barcode type and code value

---

#### **Components/Spinner.swift**
**Purpose**: Loading spinner with grace period

**Key Properties**:
- `isLoading: Bool` - Loading state
- `graceTime: TimeInterval` - Delay before showing spinner
- `showSpinner: Bool` - Internal display state

**Key Functions**:
- `.task(id: isLoading)` - Manages grace period with async/await

**Extension**: `View.spinner(_:graceTime:)` - Convenient overlay modifier

---

#### **Modifiers/PortraitLockedView.swift**
**Purpose**: Forces portrait orientation for specific views

**Key Components**:
- `PortraitHostingController` - Custom UIHostingController
- `PortraitLockedView` - SwiftUI wrapper

**Usage**: Wrap views that should be portrait-only (e.g., camera scanner)

---

#### **Modifiers/View+Extensions.swift**
**Purpose**: Utility view extensions

**Key Functions**:
- `conditionalModifier()` - Apply modifiers conditionally with ViewBuilder

**Usage**: Enables conditional view modifications without breaking view hierarchy

---

## Key Architectural Patterns

### Navigation
- Centralized `NavigationManager` with `NavigationPath`
- Type-safe routes with `NavigationRoute` enum
- Deep link support via URL scheme
- Programmatic navigation with route-specific stack building

### Data Persistence
- SwiftData for card storage
- `@Model` macro on `CardItem`
- `@Query` for reactive list updates
- In-memory mode for UI testing

### Camera Integration
- UIKit `AVCaptureSession` wrapped in SwiftUI
- `UIViewControllerRepresentable` bridge
- Proper cleanup via `dismantleUIViewController`
- Async camera start on background queue

### Performance
- Cold/warm start tracking
- OSLog signposts for debugging
- Brightness animation for barcode visibility
- Grace period for loading indicators

### Accessibility
- Comprehensive VoiceOver support
- Accessibility identifiers for UI testing
- Semantic labels and hints
- Haptic feedback for interactions

---

## Dependencies

### External Libraries
- **RSBarcodes_Swift** - Barcode generation
- **SwiftData** - Data persistence (iOS 17+)
- **AVFoundation** - Camera and barcode scanning

### System Frameworks
- SwiftUI
- UIKit (for camera and orientation control)
- Combine (implicit via SwiftUI)

---

## Testing Support

### UI Testing
- Accessibility identifiers on all interactive elements
- In-memory SwiftData for test isolation
- `-uiTesting` command line argument support

### Performance Testing
- `PerformanceTracker` logs cold/warm start times
- OSLog signposts for Instruments profiling

---

## How to Recreate This Context File

To regenerate this comprehensive project context document, follow these steps:

### 1. Scan Project Structure
```bash
# Get directory tree with depth 3
find /path/to/Cards/Cards -type d -maxdepth 3 | sort

# List all Swift files
find /path/to/Cards/Cards -name "*.swift" -type f | sort
```

### 2. Read Each File
For each Swift file discovered:
```bash
# Read file content
cat /path/to/file.swift
```

### 3. Analyze Each File
For each file, document:
- **Purpose**: What problem does this file solve?
- **Key Properties**: Important state variables
- **Key Functions**: Main methods and their responsibilities
- **Key Types**: Enums, structs, classes defined
- **Conformances**: Protocols implemented
- **Dependencies**: External libraries or frameworks used
- **Patterns**: Architectural patterns employed

### 4. Document Architecture
Identify and document:
- **Navigation patterns**: How routing works
- **Data flow**: How data moves through the app
- **State management**: How state is stored and updated
- **UI patterns**: Reusable UI components and modifiers
- **Integration patterns**: How different layers communicate

### 5. Create Directory Tree
Build a visual tree showing:
- Folder hierarchy
- File locations
- Logical groupings (App, Core, Features, UI)

### 6. Document Dependencies
List:
- External libraries (with purpose)
- System frameworks
- Minimum OS versions

### 7. Add Usage Examples
For complex patterns, include:
- Code snippets
- Usage examples
- Common workflows

### 8. Include Regeneration Instructions
Add this section explaining how to recreate the document, making it self-documenting.

### Automation Script (Optional)
```bash
#!/bin/bash
# Generate project context

PROJECT_PATH="/path/to/Cards/Cards"
OUTPUT_FILE=".amazonq/rules/CardProject.md"

echo "# Cards Project - Comprehensive Context" > $OUTPUT_FILE
echo "" >> $OUTPUT_FILE
echo "## Directory Structure" >> $OUTPUT_FILE
tree -L 3 $PROJECT_PATH >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# For each Swift file, extract key information
find $PROJECT_PATH -name "*.swift" | while read file; do
    echo "### $(basename $file)" >> $OUTPUT_FILE
    # Add file analysis here
done
```

### Manual Review
After generation:
1. Review for accuracy
2. Add architectural insights
3. Document patterns not obvious from code
4. Add examples and usage notes
5. Update with project-specific conventions

This ensures the context file remains accurate and useful as the project evolves.
