# Cards App - Project Context

## Project Overview

Cards is a SwiftUI-based iOS application for storing and displaying barcode cards (loyalty cards, membership cards, etc.). The app allows users to scan barcodes with their camera, manually enter card details, and display barcodes for scanning at point-of-sale terminals.

## Key Technologies

- **SwiftUI**: Main UI framework
- **SwiftData**: Persistence framework for storing card information
- **AVFoundation**: Camera access and barcode scanning
- **RSBarcodes_Swift**: Third-party library for barcode generation
- **UIKit Integration**: Camera controller and orientation management

## Core Features

1. **Card Management**
   - Create, edit, and delete cards
   - Reorder cards in the list
   - Store card name, barcode data, and barcode type

2. **Barcode Support**
   - Multiple barcode formats (Code 128, Code 39, QR Code, EAN-8, EAN-13, etc.)
   - Barcode generation and display
   - Camera-based barcode scanning

3. **User Experience**
   - Screen brightness adjustment when displaying barcodes
   - Portrait-only orientation for barcode display
   - Performance monitoring for app startup and resume

## Project Structure

### Models
- **CardItem**: SwiftData model for card information
  - `timestamp`: Creation date
  - `code`: Barcode data
  - `name`: Card name
  - `order`: Display order in the list
  - `type`: Barcode format type
  - `barcodeType`: Computed property for convenient access

- **BarcodeType**: Enum defining supported barcode formats
  - Maps between app's barcode types and AVFoundation's metadata types

### Views
- **ContentView**: Main list view showing all cards
- **CardItemView**: Detail view for displaying a single card with its barcode
- **EditCardItemView**: Form for creating/editing card details
- **BarcodeView**: Renders barcodes using RSBarcodes_Swift
- **CameraScannerView**: SwiftUI wrapper for the camera scanner
- **PortraitLockedView**: Utility for restricting orientation to portrait

### Controllers
- **ScannerViewController**: UIKit-based camera controller
- **ScannerViewControllerDelegate**: Protocol for handling scanned codes

### App Structure
- **CardsApp**: Main app entry point with SwiftData configuration
- **AppLifecycleTracker**: Monitors app lifecycle for performance tracking

## Development Notes

### SwiftData Usage
- Model container configured in CardsApp
- In-memory storage option for UI testing
- Manual order management for list reordering

### Barcode Handling
- RSBarcodes_Swift used for barcode generation
- AVFoundation's metadata object types for scanning
- Mapping between app's barcode types and system types

### Camera Integration
- AVCaptureSession for camera access
- Metadata output for barcode detection
- SwiftUI wrapper around UIKit camera controller

### UI/UX Considerations
- Screen brightness increased when displaying barcodes
- Smooth brightness transitions
- Portrait orientation lock for barcode display
- Accessibility identifiers for UI testing

## Testing Strategy

### Unit Tests
- Test barcode generation and mapping functions
- Test data model operations
- Test utility functions

### UI Tests
- Test card creation flow
- Test card editing and deletion
- Test barcode scanning (with mock camera)

### Performance Tests
- Measure app startup time
- Test barcode generation performance
- Test list scrolling performance with many cards

## Common Issues & Solutions

### Barcode Generation
- Ensure code string is valid for the selected barcode type
- Verify barcode dimensions are appropriate
- Check RSBarcodes_Swift integration

### SwiftData
- Verify schema migrations when model changes
- Handle threading issues (SwiftData operations on main thread)
- Validate relationships between entities

### Camera Permissions
- Info.plist needs camera usage description
- Handle permission denial gracefully

### UI Layout
- Test on different device sizes
- Check for conflicting constraints

## Code Snippets

### SwiftData Operations
```swift
// Create a new card
let newCard = CardItem(
    timestamp: Date(),
    code: "123456789",
    name: "Store Card",
    barcodeType: .code128,
    order: cardItems.count
)
modelContext.insert(newCard)

// Delete a card
modelContext.delete(cardToDelete)

// Save changes
try? modelContext.save()

// Update order after reordering
cardItems.enumerated().forEach { index, item in
    item.order = index
}
```

### Barcode Generation
```swift
let barcodeImage = RSUnifiedCodeGenerator.shared.generateCode(
    "123456789",
    machineReadableCodeObjectType: AVMetadataObject.ObjectType.code128.rawValue,
    targetSize: CGSize(width: 300, height: 100)
)
```

### Performance Monitoring
```swift
func measureTime<T>(name: String, operation: () -> T) -> T {
    let start = CFAbsoluteTimeGetCurrent()
    let result = operation()
    let end = CFAbsoluteTimeGetCurrent()
    print("\(name) took \(end - start) seconds")
    return result
}
```

## Future Enhancements

1. **Data Backup & Sync**
   - iCloud integration for syncing across devices
   - Export/import functionality

2. **Enhanced Card Management**
   - Categories/folders for organizing cards
   - Search functionality
   - Card expiration dates

3. **UI Improvements**
   - Custom card designs/themes
   - Dark mode optimization
   - Widget support for quick access

4. **Advanced Barcode Features**
   - Support for more barcode types
   - Custom barcode styling options
   - Batch scanning for multiple cards

5. **Security**
   - Biometric authentication option
   - Secure storage for sensitive cards
