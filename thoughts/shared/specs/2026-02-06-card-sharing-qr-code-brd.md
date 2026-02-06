# Business Requirements Document: Card Sharing via QR Code

**Document Version**: 1.0  
**Date**: 2026-02-06  
**Author**: serbypau  
**Status**: Draft  
**Related Research**: `thoughts/shared/research/2026-02-06-barcode-brightness-toggle.md`

---

## Executive Summary

Enable users to share card data with family, friends, or between their own devices by generating a QR code containing the card information. Recipients can scan the QR code to instantly import the card into their Cards app, eliminating manual data entry and enabling easy family sharing of loyalty cards, memberships, and other shared cards.

**Key Value**: Transform card sharing from impossible/manual to instant and effortless.

---

## 1. Business Requirements

### 1.1 Problem Statement

**Current State:**
- No way to share cards between users
- No way to transfer cards between devices
- Users must manually re-enter card data on new devices
- Family members can't share household cards (Costco, gym, etc.)

**Pain Points:**
- Manual data entry is tedious and error-prone
- No backup/restore mechanism for cards
- Family sharing requires physical card or manual typing
- Device migration requires recreating all cards
- No way to help friends/family set up same cards

**Business Impact:**
- User frustration with manual data entry
- Lost cards during device migration
- Missed opportunity for viral growth (sharing drives adoption)
- Competitive disadvantage (some card apps have sharing)

### 1.2 Proposed Solution

Add card sharing functionality that:
- Generates a QR code containing card data (name, code, barcode type)
- Allows scanning QR code to import card
- Supports sharing via QR code screenshot or in-person scan
- Includes optional password protection for sensitive cards
- Works entirely offline (no cloud dependency)
- Leverages existing camera scanner infrastructure

### 1.3 Success Metrics

**Quantitative:**
- 20%+ of users share at least one card within first month
- 40%+ of shared cards are successfully imported
- 15%+ of new users come from shared card invitations
- Average user shares 2-3 cards

**Qualitative:**
- Positive user feedback on sharing feature
- App Store reviews mentioning sharing
- Reduced support requests about "how to transfer cards"
- Increased word-of-mouth recommendations

### 1.4 Business Value

- **User Experience**: Effortless card sharing and device migration
- **Viral Growth**: Sharing drives new user acquisition
- **Family Sharing**: Enables household card sharing use case
- **Data Portability**: Users feel confident their data isn't locked in
- **Competitive Advantage**: Feature parity with leading card apps

---

## 2. Functional Requirements

### 2.1 Share Card Feature

#### FR-1: Share Button
**Priority**: P0 (Must Have)

Add "Share Card" button to card detail view.

**Acceptance Criteria:**
- Button appears in toolbar or action menu
- Button uses SF Symbol `square.and.arrow.up` (standard share icon)
- Button is visible on all card detail views
- Tapping button presents share sheet

#### FR-2: QR Code Generation
**Priority**: P0 (Must Have)

Generate QR code containing card data.

**Data Format (JSON):**
```json
{
  "version": 1,
  "name": "Starbucks Rewards",
  "code": "1234567890123",
  "type": "code128",
  "timestamp": "2026-02-06T12:00:00Z",
  "appIdentifier": "com.serby.cards"
}
```

**Acceptance Criteria:**
- QR code contains complete card data as JSON
- QR code includes version number for future compatibility
- QR code includes app identifier for validation
- QR code includes timestamp for tracking
- QR code is generated using existing BarcodeView infrastructure (type: .qrCode)
- QR code is large enough to scan reliably (400x400 points minimum)

#### FR-3: Share Sheet Presentation
**Priority**: P0 (Must Have)

Present iOS share sheet with QR code image.

**Acceptance Criteria:**
- Share sheet shows QR code as image
- Share sheet includes card name in message: "Scan to import [Card Name]"
- User can share via: Messages, Mail, AirDrop, Save to Photos, Copy
- Share sheet follows iOS native patterns
- QR code image is high resolution (suitable for printing)

### 2.2 Import Card Feature

#### FR-4: Scan to Import
**Priority**: P0 (Must Have)

Detect and import cards from scanned QR codes.

**Acceptance Criteria:**
- Existing camera scanner detects QR codes (already supported)
- App recognizes QR codes containing card data (checks appIdentifier)
- App parses JSON from QR code
- App validates data format and required fields
- App presents import confirmation dialog
- User can review card details before importing
- User can cancel import

#### FR-5: Import Confirmation Dialog
**Priority**: P0 (Must Have)

Show confirmation before importing card.

**Dialog Content:**
```
Import Card?

Name: Starbucks Rewards
Code: 1234567890123
Type: Code 128

[Cancel] [Import]
```

**Acceptance Criteria:**
- Dialog shows all card details for review
- User can see what will be imported
- Cancel button dismisses dialog (no import)
- Import button adds card to collection
- Dialog follows iOS alert/sheet patterns

#### FR-6: Duplicate Handling
**Priority**: P0 (Must Have)

Handle importing duplicate cards gracefully.

**Acceptance Criteria:**
- App detects if card with same code already exists
- If duplicate: Show dialog "Card already exists. Import anyway?"
- Options: "Replace Existing", "Keep Both", "Cancel"
- Replace: Updates existing card with new data
- Keep Both: Adds as new card (allows duplicates)
- Cancel: Dismisses without importing

### 2.3 Security & Privacy

#### FR-7: Password Protection (Optional)
**Priority**: P1 (Should Have)

Allow users to password-protect shared cards.

**Acceptance Criteria:**
- Share sheet includes "Add Password" toggle
- When enabled, user enters password (4-6 digits)
- Password is hashed and included in QR code data
- Recipient must enter password to import
- Wrong password shows error and prevents import
- Password is not stored in app (only in QR code)

**Data Format with Password:**
```json
{
  "version": 1,
  "name": "Starbucks Rewards",
  "code": "1234567890123",
  "type": "code128",
  "timestamp": "2026-02-06T12:00:00Z",
  "appIdentifier": "com.serby.cards",
  "passwordHash": "sha256_hash_here",
  "encrypted": true
}
```

#### FR-8: Privacy Warning
**Priority**: P0 (Must Have)

Warn users about sharing sensitive card data.

**Acceptance Criteria:**
- First time sharing shows privacy alert
- Alert text: "Sharing a card will create a QR code containing the card name and barcode. Anyone who scans this code can import the card. Only share cards you're comfortable others having access to."
- Alert has "Don't Show Again" checkbox
- Alert has "Cancel" and "Continue" buttons
- Warning preference stored in @AppStorage

### 2.4 User Experience Enhancements

#### FR-9: Share History (Optional)
**Priority**: P2 (Nice to Have)

Track which cards have been shared.

**Acceptance Criteria:**
- Card model includes `lastShared: Date?` property
- Timestamp updated when card is shared
- Card detail view shows "Last shared: [date]" (if shared)
- No limit on sharing frequency

#### FR-10: Import Success Feedback
**Priority**: P0 (Must Have)

Provide clear feedback after successful import.

**Acceptance Criteria:**
- Success alert: "Card imported successfully!"
- Alert includes "View Card" button
- Tapping "View Card" navigates to imported card detail
- Haptic feedback on successful import
- Card appears in card list immediately

---

## 3. Technical Requirements

### 3.1 QR Code Generation

#### TR-1: QR Code Generator
**Implementation:**
- Reuse existing BarcodeView component with type `.qrCode`
- Create CardItemDTO JSON string
- Generate QR code from JSON string
- Render at 400x400 points minimum for scanning reliability
- Export as UIImage for sharing

**Code Location:**
- Create: `Core/Services/CardSharingService.swift`
- Method: `generateShareQRCode(for card: CardItem) -> UIImage?`

#### TR-2: Data Serialization
**Implementation:**
- Use existing `CardItemDTO` struct (already Codable)
- Add metadata fields: version, timestamp, appIdentifier
- Encode to JSON using `JSONEncoder`
- Handle encoding errors gracefully

**Data Structure:**
```swift
struct ShareableCard: Codable {
    let version: Int = 1
    let name: String
    let code: String
    let type: String
    let timestamp: Date
    let appIdentifier: String = "com.serby.cards"
    let passwordHash: String?
    let encrypted: Bool
}
```

### 3.2 QR Code Scanning & Import

#### TR-3: QR Code Detection
**Implementation:**
- Existing scanner already detects QR codes (AVMetadataObject.ObjectType.qr)
- Add logic to check if QR code contains card data
- Check for `appIdentifier` field in JSON
- If valid card data: Show import dialog
- If not card data: Continue normal barcode flow

**Code Location:**
- Modify: `Features/Scanner/Views/ScannerViewControllerDelegate.swift`
- Add: `isCardShareQRCode(_ string: String) -> Bool`
- Add: `parseCardShareData(_ string: String) -> ShareableCard?`

#### TR-4: Data Deserialization
**Implementation:**
- Parse JSON string from QR code
- Decode using `JSONDecoder`
- Validate required fields exist
- Validate version compatibility
- Validate appIdentifier matches
- Handle parsing errors gracefully

#### TR-5: Card Import Logic
**Implementation:**
- Create CardItem from ShareableCard data
- Check for duplicates (query by code)
- Insert into SwiftData ModelContext
- Navigate to imported card detail view

**Code Location:**
- Create: `Core/Services/CardImportService.swift`
- Method: `importCard(from shareData: ShareableCard) throws -> CardItem`

### 3.3 Share Sheet Integration

#### TR-6: Share Sheet Presentation
**Implementation:**
- Generate QR code image
- Create UIActivityViewController with image
- Add custom message: "Scan to import [Card Name]"
- Present share sheet modally
- Handle share completion/cancellation

**Code Location:**
- Modify: `Features/CardDetail/Views/CardItemView.swift`
- Add share button to toolbar
- Add `.sheet(isPresented:)` modifier for share sheet

### 3.4 Password Protection (Optional)

#### TR-7: Password Hashing
**Implementation:**
- Use SHA-256 for password hashing
- Salt with card code for uniqueness
- Include hash in QR code JSON
- Verify password on import by comparing hashes

**Code Location:**
- Add to: `Core/Services/CardSharingService.swift`
- Method: `hashPassword(_ password: String, salt: String) -> String`

#### TR-8: Password Prompt
**Implementation:**
- Detect `encrypted: true` in QR code data
- Show password entry alert before import
- Validate password hash matches
- Show error if password incorrect
- Allow 3 attempts before canceling

---

## 4. Testing Requirements

### 4.1 Unit Tests

#### UT-1: QR Code Generation Tests
**File**: `CardsTests/CardSharingServiceTests.swift` (new)

**Test Cases:**
- [ ] Test QR code generation from CardItem
- [ ] Test JSON serialization includes all required fields
- [ ] Test QR code image is generated successfully
- [ ] Test QR code is scannable (validate format)
- [ ] Test password hashing is consistent
- [ ] Test password hash validation works

#### UT-2: Data Parsing Tests
**File**: `CardsTests/CardImportServiceTests.swift` (new)

**Test Cases:**
- [ ] Test JSON parsing from QR code string
- [ ] Test valid card data is parsed correctly
- [ ] Test invalid JSON returns nil
- [ ] Test missing required fields returns error
- [ ] Test version compatibility checking
- [ ] Test appIdentifier validation

#### UT-3: Import Logic Tests
**Test Cases:**
- [ ] Test card import creates new CardItem
- [ ] Test duplicate detection works correctly
- [ ] Test imported card has correct properties
- [ ] Test import updates SwiftData context
- [ ] Test import handles errors gracefully

### 4.2 Integration Tests

#### IT-1: End-to-End Sharing Tests
**File**: `CardsTests/SharingIntegrationTests.swift` (new)

**Test Cases:**
- [ ] Test share → generate QR → parse QR → import card flow
- [ ] Test shared card matches original card data
- [ ] Test password-protected sharing works end-to-end
- [ ] Test duplicate handling works correctly
- [ ] Test invalid QR codes are rejected

### 4.3 UI Tests

#### UIT-1: Share Flow Tests
**File**: `CardsUITests/CardSharingUITests.swift` (new)

**Test Cases:**
- [ ] Test share button exists in card detail view
- [ ] Test tapping share button shows share sheet
- [ ] Test share sheet contains QR code image
- [ ] Test share sheet can be dismissed
- [ ] Test privacy warning appears on first share
- [ ] Test privacy warning can be dismissed

#### UIT-2: Import Flow Tests
**Test Cases:**
- [ ] Test scanning card QR code shows import dialog
- [ ] Test import dialog shows correct card details
- [ ] Test tapping Import adds card to list
- [ ] Test tapping Cancel dismisses dialog
- [ ] Test duplicate dialog appears for existing cards
- [ ] Test password prompt appears for protected cards
- [ ] Test wrong password shows error
- [ ] Test correct password imports card

### 4.4 Manual Testing Checklist

#### MT-1: Share Functionality
- [ ] Share button appears in card detail view
- [ ] Tapping share button generates QR code
- [ ] QR code is clear and scannable
- [ ] Share sheet appears with QR code image
- [ ] Can share via Messages, Mail, AirDrop
- [ ] Can save QR code to Photos
- [ ] Can copy QR code image
- [ ] Privacy warning appears on first share
- [ ] Privacy warning can be dismissed permanently

#### MT-2: Import Functionality
- [ ] Scanner detects card QR codes
- [ ] Import dialog appears with card details
- [ ] Card details are displayed correctly
- [ ] Tapping Import adds card successfully
- [ ] Tapping Cancel dismisses without importing
- [ ] Success message appears after import
- [ ] Imported card appears in card list
- [ ] Can navigate to imported card

#### MT-3: Duplicate Handling
- [ ] Scanning duplicate card shows duplicate dialog
- [ ] "Replace Existing" updates existing card
- [ ] "Keep Both" adds new card
- [ ] "Cancel" dismisses without importing
- [ ] Duplicate detection works correctly

#### MT-4: Password Protection
- [ ] Can enable password protection when sharing
- [ ] Password entry field appears
- [ ] Password is required to import protected card
- [ ] Correct password imports successfully
- [ ] Wrong password shows error
- [ ] Can retry password entry
- [ ] Can cancel password-protected import

#### MT-5: Edge Cases
- [ ] Sharing card with very long name works
- [ ] Sharing card with special characters works
- [ ] Scanning non-card QR code doesn't crash
- [ ] Scanning invalid JSON doesn't crash
- [ ] Scanning QR code from different app is ignored
- [ ] Importing card with missing fields shows error
- [ ] QR code works when printed on paper
- [ ] QR code works from phone screen to phone camera

#### MT-6: Cross-Device Testing
- [ ] Share from iPhone, import on different iPhone
- [ ] Share from iPhone, import on iPad (if supported)
- [ ] QR code screenshot can be imported
- [ ] QR code from email can be imported
- [ ] QR code from Messages can be imported

### 4.5 Security Testing

#### ST-1: Security Validation
- [ ] Password hashing is secure (SHA-256)
- [ ] Password is not stored in plain text
- [ ] QR code doesn't expose sensitive data beyond card info
- [ ] Invalid password attempts are limited
- [ ] No security vulnerabilities in JSON parsing

---

## 5. Implementation Phases

### Phase 1: Core Sharing Infrastructure (4-6 hours)
**Tasks:**
- Create CardSharingService
- Implement ShareableCard data structure
- Implement JSON serialization
- Implement QR code generation
- Add share button to CardItemView
- Test QR code generation

**Success Criteria:**
- Can generate QR code from card
- QR code contains valid JSON
- Share button appears and works

### Phase 2: Share Sheet Integration (2-3 hours)
**Tasks:**
- Implement share sheet presentation
- Add QR code image to share sheet
- Add custom share message
- Implement privacy warning dialog
- Test sharing via different methods

**Success Criteria:**
- Share sheet appears with QR code
- Can share via Messages, Mail, AirDrop
- Privacy warning works correctly

### Phase 3: Import Detection (3-4 hours)
**Tasks:**
- Modify scanner to detect card QR codes
- Implement JSON parsing
- Implement data validation
- Add appIdentifier checking
- Test QR code detection

**Success Criteria:**
- Scanner detects card QR codes
- JSON parsing works correctly
- Invalid QR codes are rejected

### Phase 4: Import Dialog & Logic (4-5 hours)
**Tasks:**
- Create import confirmation dialog
- Implement card import logic
- Add duplicate detection
- Implement duplicate handling dialog
- Add success feedback
- Test import flow

**Success Criteria:**
- Import dialog shows card details
- Import adds card to collection
- Duplicate handling works correctly
- Success feedback appears

### Phase 5: Password Protection (3-4 hours)
**Tasks:**
- Implement password hashing
- Add password entry to share sheet
- Add password prompt on import
- Implement password validation
- Test password protection

**Success Criteria:**
- Can add password when sharing
- Password prompt appears on import
- Password validation works correctly

### Phase 6: Testing & Polish (4-6 hours)
**Tasks:**
- Write unit tests
- Write integration tests
- Write UI tests
- Perform manual testing
- Fix bugs
- Polish UI/UX

**Success Criteria:**
- All automated tests pass
- All manual test cases pass
- No critical bugs
- UI is polished

**Total Estimated Effort**: 20-28 hours

---

## 6. User Experience Specifications

### 6.1 User Flows

**Primary Flow: Share Card**
1. User opens card detail view
2. User taps share button in toolbar
3. (First time) Privacy warning appears
4. User taps "Continue"
5. QR code is generated
6. Share sheet appears with QR code
7. User selects share method (Messages, AirDrop, etc.)
8. QR code is shared

**Primary Flow: Import Card**
1. User receives QR code (via Messages, email, etc.)
2. User opens Cards app
3. User taps scanner button
4. User scans QR code
5. Import dialog appears showing card details
6. User reviews details
7. User taps "Import"
8. Success message appears
9. User taps "View Card" to see imported card

**Alternative Flow: Duplicate Card**
1. User scans QR code for existing card
2. Duplicate dialog appears
3. User selects "Replace Existing", "Keep Both", or "Cancel"
4. Card is updated/added/canceled accordingly

**Alternative Flow: Password-Protected Card**
1. User scans password-protected QR code
2. Password prompt appears
3. User enters password
4. If correct: Import proceeds
5. If incorrect: Error shown, can retry

### 6.2 Visual Design

**Share Button:**
- Icon: `square.and.arrow.up` (SF Symbol)
- Location: Toolbar, trailing position
- Color: `.accent`

**QR Code Display:**
- Size: 400x400 points
- Background: White
- Padding: 20 points
- Border: Optional subtle border

**Import Dialog:**
```
┌─────────────────────────────┐
│      Import Card?           │
├─────────────────────────────┤
│                             │
│  Name: Starbucks Rewards    │
│  Code: 1234567890123        │
│  Type: Code 128             │
│                             │
├─────────────────────────────┤
│  [Cancel]        [Import]   │
└─────────────────────────────┘
```

**Duplicate Dialog:**
```
┌─────────────────────────────┐
│   Card Already Exists       │
├─────────────────────────────┤
│                             │
│  A card with this code      │
│  already exists.            │
│                             │
│  What would you like to do? │
│                             │
├─────────────────────────────┤
│  [Cancel]                   │
│  [Replace Existing]         │
│  [Keep Both]                │
└─────────────────────────────┘
```

---

## 7. Out of Scope

The following items are explicitly **NOT** included in this BRD:

- Cloud-based sharing (all sharing is via QR code)
- Sharing multiple cards at once (one card per QR code)
- Sharing via URL/deep link (only QR code)
- Expiring share links (QR codes don't expire)
- Share analytics/tracking (no tracking of who imports)
- Bulk import from CSV/JSON file
- Export all cards feature (separate feature)
- Share card collections/folders
- Social media sharing integration
- NFC sharing (only QR code)

---

## 8. Risks & Mitigations

### Risk 1: QR Code Size Limitations
**Risk**: Complex card data might create large QR codes that are hard to scan.

**Mitigation**:
- Keep data minimal (only essential fields)
- Test QR code scanning at various sizes
- Use high error correction level
- Ensure QR code is at least 400x400 points

**Likelihood**: Low  
**Impact**: Medium

### Risk 2: Privacy Concerns
**Risk**: Users might accidentally share sensitive cards publicly.

**Mitigation**:
- Show privacy warning on first share
- Make password protection easily accessible
- Clear messaging about what's being shared
- Consider per-card "shareable" flag (future)

**Likelihood**: Medium  
**Impact**: High

### Risk 3: Duplicate Card Confusion
**Risk**: Users might be confused by duplicate handling options.

**Mitigation**:
- Clear dialog text explaining options
- Default to "Replace Existing" (most common case)
- Show card details in duplicate dialog
- Test with real users

**Likelihood**: Medium  
**Impact**: Low

### Risk 4: Cross-Version Compatibility
**Risk**: Future app versions might change data format.

**Mitigation**:
- Include version number in QR code data
- Implement version checking on import
- Maintain backwards compatibility
- Document data format changes

**Likelihood**: Low  
**Impact**: Medium

---

## 9. Success Criteria

### Definition of Done

This feature is considered complete when:

1. **Functional Requirements Met**:
   - [ ] Share button generates QR code
   - [ ] QR code contains valid card data
   - [ ] Share sheet works with all share methods
   - [ ] Scanner detects card QR codes
   - [ ] Import dialog shows card details
   - [ ] Import adds card to collection
   - [ ] Duplicate handling works correctly
   - [ ] Password protection works (optional)
   - [ ] Privacy warning appears on first share

2. **Testing Complete**:
   - [ ] All unit tests pass
   - [ ] All integration tests pass
   - [ ] All UI tests pass
   - [ ] Manual testing checklist completed
   - [ ] Cross-device testing completed
   - [ ] Security testing completed
   - [ ] No critical bugs

3. **Quality Standards Met**:
   - [ ] QR codes are reliably scannable
   - [ ] UI follows iOS design guidelines
   - [ ] Error handling is robust
   - [ ] Performance is acceptable
   - [ ] Privacy controls work correctly

4. **Documentation Complete**:
   - [ ] Code is documented
   - [ ] Data format is documented
   - [ ] User-facing help text added (if needed)

---

## 10. Future Enhancements

Ideas for future iterations (not in scope for v1):

1. **Bulk Sharing**: Share multiple cards in one QR code
2. **Expiring Shares**: QR codes that expire after X days
3. **Share Analytics**: Track how many times card was imported
4. **Cloud Sharing**: Share via URL instead of QR code
5. **NFC Sharing**: Tap phones to share cards
6. **Share Templates**: Pre-configured share settings per card
7. **Family Sharing**: Dedicated family sharing with permissions
8. **Share History**: View all shared cards and when

---

## 11. Appendix

### A. Related Documents
- Research: `thoughts/shared/research/2026-02-06-barcode-brightness-toggle.md`
- Implementation Plan: TBD

### B. Technical References
- QR Code Generation: Core Image CIQRCodeGenerator
- JSON Encoding/Decoding: Swift Codable
- SHA-256 Hashing: CryptoKit
- Share Sheet: UIActivityViewController

### C. Data Format Specification

**Version 1 Format:**
```json
{
  "version": 1,
  "name": "string",
  "code": "string",
  "type": "string",
  "timestamp": "ISO8601 date string",
  "appIdentifier": "com.serby.cards",
  "passwordHash": "string (optional)",
  "encrypted": boolean
}
```

**Required Fields:**
- version, name, code, type, timestamp, appIdentifier

**Optional Fields:**
- passwordHash, encrypted

### D. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-06 | serbypau | Initial draft |

---

## 12. Approval

**Product Owner**: ___________________ Date: ___________

**Engineering Lead**: ___________________ Date: ___________

**QA Lead**: ___________________ Date: ___________
