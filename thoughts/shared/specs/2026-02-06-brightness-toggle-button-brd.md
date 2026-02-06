# Business Requirements Document: Brightness Toggle Button

**Document Version**: 1.0  
**Date**: 2026-02-06  
**Author**: serbypau  
**Status**: Draft  
**Related Research**: `thoughts/shared/research/2026-02-06-barcode-brightness-toggle.md`

---

## Executive Summary

Add an in-context brightness toggle button to the card detail view, allowing users to control screen brightness directly while viewing barcodes without navigating to Settings. This improves usability by providing immediate access to brightness control at the point of need.

---

## 1. Business Requirements

### 1.1 Problem Statement

**Current State:**
- Users must navigate to Settings tab to enable/disable brightness boost
- Brightness control is separated from the barcode viewing context
- Users cannot quickly toggle brightness while actively using a barcode

**Pain Points:**
- Extra navigation steps to change brightness preference
- Brightness setting is "set and forget" rather than contextual
- No visual feedback on card view about current brightness state

**Business Impact:**
- Reduced user efficiency when scanning barcodes in varying lighting conditions
- Missed opportunity for contextual control at point of use

### 1.2 Proposed Solution

Add a brightness toggle button to the card detail view toolbar that:
- Provides immediate brightness control without leaving the card view
- Updates the global brightness preference setting
- Syncs bidirectionally with the Settings toggle
- Follows iOS design guidelines and accessibility standards

### 1.3 Success Metrics

- Reduced navigation to Settings for brightness changes
- Increased usage of brightness boost feature (measurable via analytics)
- Positive user feedback on convenience
- Zero increase in support requests or confusion

### 1.4 Business Value

- **User Experience**: Faster, more intuitive brightness control
- **Accessibility**: Better support for users with visual needs
- **Competitive Advantage**: More polished, thoughtful UX than competitors
- **Retention**: Small quality-of-life improvements increase user satisfaction

---

## 2. Functional Requirements

### 2.1 Core Functionality

#### FR-1: Brightness Toggle Button
**Priority**: P0 (Must Have)

The card detail view shall display a brightness toggle button in the navigation toolbar.

**Acceptance Criteria:**
- Button appears in trailing position of toolbar, before the Edit button
- Button uses SF Symbol `sun.max.fill` icon
- Button is visible on all card detail views
- Button does not obscure barcode or card information
- Button follows iOS native toolbar styling

#### FR-2: Toggle Behavior
**Priority**: P0 (Must Have)

When the user taps the brightness toggle button:
1. Screen brightness immediately changes (increase to 1.0 or restore to original)
2. Global `brightnessBoost` @AppStorage setting updates
3. Button visual state updates to reflect new state
4. Brightness transition uses smooth fade animation (0.5s)

**Acceptance Criteria:**
- Tapping button toggles brightness between boosted (1.0) and original level
- Setting persists across app sessions via @AppStorage
- Animation matches existing brightness fade behavior (0.5s fade in, 0.2s fade out)
- No lag or delay in visual feedback

#### FR-3: State Synchronization
**Priority**: P0 (Must Have)

The button state shall remain synchronized with the Settings toggle.

**Acceptance Criteria:**
- Changing button on card view updates Settings toggle
- Changing Settings toggle updates button on card view (when visible)
- Both controls always show the same state
- State persists when navigating between views

#### FR-4: Visual Feedback
**Priority**: P0 (Must Have)

The button shall provide clear visual feedback of current brightness state.

**Acceptance Criteria:**
- When brightness boost is ON: button shows filled sun icon with accent color
- When brightness boost is OFF: button shows regular sun icon with default color
- Button state is immediately visible without interaction
- Visual state matches actual brightness behavior

### 2.2 Edge Cases & Error Handling

#### FR-5: Brightness Restoration
**Priority**: P0 (Must Have)

When user navigates away from card view with brightness boosted:
- Original brightness is restored with fade animation (0.2s)
- Setting remains saved for next card view
- No brightness flicker or abrupt changes

#### FR-6: Rapid Toggle Handling
**Priority**: P1 (Should Have)

If user rapidly taps the toggle button:
- Each tap is processed in sequence
- No animation conflicts or visual glitches
- Final state matches last tap

### 2.3 Accessibility Requirements

#### FR-7: VoiceOver Support
**Priority**: P0 (Must Have)

**Acceptance Criteria:**
- Button has accessibility label: "Brightness Boost"
- Button has accessibility hint: "Toggles screen brightness to maximum for easier barcode scanning"
- Button announces state changes: "Brightness boost on" / "Brightness boost off"
- Button is discoverable via VoiceOver navigation

#### FR-8: Dynamic Type Support
**Priority**: P1 (Should Have)

- Button scales appropriately with system text size settings
- Icon remains visible and tappable at all text sizes

---

## 3. Technical Requirements

### 3.1 Implementation Details

#### TR-1: Component Location
- **File**: `Features/CardDetail/Views/CardItemView.swift`
- **Location**: Toolbar, trailing position, before Edit button
- **Implementation**: Add new toolbar item with Button view

#### TR-2: State Management
- **Storage**: Use existing `@AppStorage("brightnessBoost")` property
- **Binding**: Button directly modifies @AppStorage value
- **Sync**: SwiftUI automatically syncs @AppStorage across views

#### TR-3: Icon Assets
- **Icon**: SF Symbol `sun.max.fill` (when ON) / `sun.max` (when OFF)
- **Color**: `.accent` (when ON) / `.primary` (when OFF)
- **Size**: System default toolbar icon size

#### TR-4: Animation
- **Reuse**: Existing `fadeBrightness()` function in CardItemView
- **Timing**: 0.5s fade in, 0.2s fade out (existing behavior)
- **Trigger**: Button tap triggers brightness change via @AppStorage update

### 3.2 Code Patterns to Follow

Based on existing codebase patterns:
- Use SwiftUI declarative syntax
- Follow existing toolbar button pattern from Edit button
- Reuse existing brightness management logic
- Maintain accessibility identifier pattern: `accessibilityIdentifier("brightnessToggleButton")`
- Use existing color scheme (`.accent` for primary actions)

### 3.3 Dependencies

- **Existing Code**: Leverages current brightness management in CardItemView
- **No New Libraries**: Uses built-in SwiftUI and UIKit APIs
- **No Breaking Changes**: Additive feature, no modifications to existing behavior

---

## 4. Testing Requirements

### 4.1 Unit Tests

#### UT-1: State Management
**File**: `CardsTests/CardItemViewTests.swift` (new or extend existing)

**Test Cases:**
- [ ] Test brightness toggle updates @AppStorage value
- [ ] Test @AppStorage value persists across view lifecycle
- [ ] Test initial button state reflects stored preference
- [ ] Test button state updates when @AppStorage changes externally

#### UT-2: Brightness Control
**Test Cases:**
- [ ] Test brightness increases to 1.0 when toggled ON
- [ ] Test brightness restores to original when toggled OFF
- [ ] Test original brightness is captured correctly on view appear
- [ ] Test brightness restoration on view disappear

### 4.2 UI Tests

#### UIT-1: Button Interaction
**File**: `CardsUITests/CardsUITests.swift`

**Test Cases:**
- [ ] Test brightness toggle button exists in toolbar
- [ ] Test button is tappable
- [ ] Test button tap changes visual state
- [ ] Test button tap changes screen brightness (verify via UIScreen.main.brightness)
- [ ] Test rapid taps don't cause crashes or visual glitches

#### UIT-2: State Synchronization
**Test Cases:**
- [ ] Test toggling button updates Settings toggle
- [ ] Test toggling Settings updates button (navigate to card view after)
- [ ] Test state persists after app restart
- [ ] Test state persists when navigating between cards

#### UIT-3: Accessibility
**Test Cases:**
- [ ] Test VoiceOver can discover button
- [ ] Test VoiceOver announces correct label and hint
- [ ] Test VoiceOver announces state changes
- [ ] Test button remains tappable with VoiceOver enabled

### 4.3 Manual Testing Checklist

#### MT-1: Visual Verification
- [ ] Button appears in correct toolbar position
- [ ] Button icon is clear and recognizable
- [ ] Button color changes appropriately (accent when ON, default when OFF)
- [ ] Button doesn't obscure barcode or card content
- [ ] Button looks correct in light and dark mode

#### MT-2: Functional Verification
- [ ] Tapping button immediately changes brightness
- [ ] Brightness change is smooth with fade animation
- [ ] Button state visually updates on tap
- [ ] Settings toggle reflects button changes
- [ ] Button reflects Settings toggle changes

#### MT-3: Edge Cases
- [ ] Test with multiple cards (state persists correctly)
- [ ] Test with rapid tapping (no crashes or glitches)
- [ ] Test with low battery mode (brightness still works)
- [ ] Test with auto-brightness enabled (manual override works)
- [ ] Test brightness restoration when navigating away

#### MT-4: Accessibility Verification
- [ ] Test with VoiceOver enabled
- [ ] Test with largest text size
- [ ] Test with reduced motion enabled
- [ ] Test with high contrast mode

### 4.4 Regression Testing

#### RT-1: Existing Functionality
- [ ] Edit button still works correctly
- [ ] Barcode displays correctly
- [ ] Navigation still works
- [ ] Settings toggle still works independently
- [ ] Existing brightness auto-boost on view appear still works

### 4.5 Performance Testing

#### PT-1: Performance Metrics
- [ ] Button tap response time < 100ms
- [ ] Brightness animation is smooth (60fps)
- [ ] No memory leaks from repeated toggling
- [ ] No impact on app launch time

---

## 5. User Experience Specifications

### 5.1 User Flow

**Primary Flow:**
1. User navigates to card detail view
2. User sees barcode with current brightness
3. User notices brightness toggle button in toolbar
4. User taps button to boost brightness
5. Screen brightness smoothly increases to maximum
6. Button visual state updates to show "ON" state
7. User scans barcode with improved visibility
8. User taps button again to restore normal brightness
9. Screen brightness smoothly returns to original level
10. Button visual state updates to show "OFF" state

**Alternative Flow (Settings):**
1. User goes to Settings tab
2. User toggles "Brightness Boost" setting
3. User returns to card view
4. Button state reflects Settings change
5. Brightness behavior matches setting

### 5.2 Visual Design

**Button States:**

| State | Icon | Color | Accessibility |
|-------|------|-------|---------------|
| OFF | `sun.max` | `.primary` | "Brightness boost off" |
| ON | `sun.max.fill` | `.accent` | "Brightness boost on" |

**Layout:**
```
┌─────────────────────────────────┐
│  Card Name            ☀️  ✏️   │ ← Toolbar
├─────────────────────────────────┤
│                                 │
│      [Barcode Display]          │
│                                 │
├─────────────────────────────────┤
│  Card Code: 1234567890          │
│  Created: Jan 1, 2026           │
└─────────────────────────────────┘
```

### 5.3 Interaction Design

**Tap Behavior:**
- Single tap toggles state
- No long-press behavior
- No swipe gestures
- Standard iOS button haptic feedback

**Animation:**
- Brightness fade: 0.5s ease-in-out (boost ON)
- Brightness fade: 0.2s ease-in-out (boost OFF)
- Icon change: Instant
- Color change: Instant

---

## 6. Implementation Phases

### Phase 1: Core Button Implementation
**Estimated Effort**: 2-4 hours

**Tasks:**
- Add brightness toggle button to CardItemView toolbar
- Wire button to @AppStorage("brightnessBoost")
- Implement visual state changes (icon/color)
- Add accessibility labels and hints

**Success Criteria:**
- Button appears and is tappable
- Button updates @AppStorage value
- Visual state reflects current setting

### Phase 2: Brightness Integration
**Estimated Effort**: 1-2 hours

**Tasks:**
- Connect button tap to brightness change logic
- Ensure smooth animation reuse
- Test state synchronization with Settings

**Success Criteria:**
- Tapping button changes brightness immediately
- Settings toggle stays in sync
- Animations are smooth

### Phase 3: Testing & Polish
**Estimated Effort**: 3-4 hours

**Tasks:**
- Write unit tests for state management
- Write UI tests for button interaction
- Perform manual testing checklist
- Test accessibility features
- Fix any bugs found

**Success Criteria:**
- All automated tests pass
- All manual test cases pass
- No regressions in existing features

---

## 7. Additional Feature Ideas

Based on the Cards app architecture and user needs, here are 3 additional feature ideas:

### Idea 1: Quick Actions Widget
**Description**: iOS Home Screen widget showing recently used cards with quick access to barcode view.

**Value Proposition:**
- Instant access to frequently used cards without opening app
- Reduces friction for common use cases (gym card, loyalty cards)
- Leverages iOS 14+ widget capabilities

**Technical Feasibility**: High
- SwiftUI WidgetKit support
- Can reuse existing BarcodeView component
- SwiftData integration for recent cards

**User Benefit**: 
- Save 3-4 taps for frequently accessed cards
- Better integration with iOS ecosystem
- Competitive feature (many card apps lack good widgets)

**Implementation Complexity**: Medium
- Requires WidgetKit extension
- Widget refresh logic
- Privacy considerations for lock screen

---

### Idea 2: Card Sharing via QR Code
**Description**: Generate a QR code containing card data for easy sharing with family/friends.

**Value Proposition:**
- Share loyalty cards with family members
- Transfer cards between devices
- Backup/restore via QR code scan

**Technical Feasibility**: High
- Already have QR code generation (BarcodeType.qrCode)
- Can encode CardItem as JSON
- Use existing camera scanner for import

**User Benefit**:
- Family sharing of household cards (Costco, gym memberships)
- Easy device migration
- No cloud dependency for sharing

**Implementation Complexity**: Low-Medium
- Add "Share Card" button to card detail view
- Generate QR code with card JSON data
- Add import flow from scanner
- Handle data validation and security

**Privacy Considerations**:
- Warn users about sharing sensitive card data
- Optional password protection for shared QR codes
- Expiring share links

---

### Idea 3: Smart Card Organization with Categories & Tags
**Description**: Add categories, tags, and smart folders to organize cards beyond a flat list.

**Value Proposition:**
- Better organization for users with many cards (10+)
- Quick filtering and search
- Contextual card suggestions (location-based, time-based)

**Technical Feasibility**: High
- SwiftData supports relationships and filtering
- Can add Category model with many-to-many relationship
- Existing navigation patterns support nested views

**User Benefit**:
- Find cards faster ("Show me all retail cards")
- Reduce visual clutter in main list
- Smart suggestions ("You're near Starbucks, here's your card")

**Implementation Complexity**: Medium-High
- Database schema changes (add Category model)
- UI for category management
- Filtering and search logic
- Optional: Location-based suggestions (requires CoreLocation)

**Feature Breakdown**:
- **Categories**: Retail, Membership, Transit, Healthcare, etc.
- **Tags**: Custom user tags (favorites, expired, shared)
- **Smart Folders**: Auto-generated based on rules
- **Search**: Full-text search across card names and codes
- **Filters**: Quick filter buttons in card list

---

## 8. Out of Scope

The following items are explicitly **NOT** included in this BRD:

- Automatic brightness adjustment based on ambient light
- Per-card brightness preferences (different brightness per card)
- Brightness scheduling (time-based brightness rules)
- Battery impact warnings or optimizations
- Brightness control for other views (only card detail view)
- Changes to Settings view layout or design
- Removal of Settings toggle (both controls coexist)

---

## 9. Risks & Mitigations

### Risk 1: User Confusion (Two Controls)
**Risk**: Users might be confused by having brightness control in two places.

**Mitigation**:
- Clear labeling in both locations
- Consistent visual design
- Settings includes hint text: "Can also be toggled from card view"

**Likelihood**: Low  
**Impact**: Low

### Risk 2: Battery Drain
**Risk**: Users leaving brightness boost on could drain battery faster.

**Mitigation**:
- Brightness auto-restores when leaving card view
- Setting is per-session, not permanent boost
- Consider adding battery warning in Settings (future enhancement)

**Likelihood**: Medium  
**Impact**: Low

### Risk 3: Accessibility Issues
**Risk**: Button might not be accessible to all users.

**Mitigation**:
- Full VoiceOver support
- Proper accessibility labels and hints
- Follows iOS HIG for toolbar buttons
- Testing with accessibility features enabled

**Likelihood**: Low  
**Impact**: Medium

---

## 10. Success Criteria

### Definition of Done

This feature is considered complete when:

1. **Functional Requirements Met**:
   - [ ] Brightness toggle button appears in card detail toolbar
   - [ ] Button toggles brightness immediately on tap
   - [ ] Button updates global @AppStorage setting
   - [ ] Button syncs with Settings toggle bidirectionally
   - [ ] Visual feedback clearly shows ON/OFF state

2. **Testing Complete**:
   - [ ] All unit tests pass
   - [ ] All UI tests pass
   - [ ] Manual testing checklist completed
   - [ ] Accessibility testing completed
   - [ ] No regressions in existing features

3. **Quality Standards Met**:
   - [ ] Code follows existing patterns and conventions
   - [ ] Accessibility labels and hints implemented
   - [ ] Performance is acceptable (no lag or jank)
   - [ ] Works correctly in light and dark mode

4. **Documentation Complete**:
   - [ ] Code comments added for new functionality
   - [ ] Test documentation updated
   - [ ] User-facing changes documented (if applicable)

---

## 11. Appendix

### A. Related Documents
- Research: `thoughts/shared/research/2026-02-06-barcode-brightness-toggle.md`
- Implementation Plan: TBD

### B. References
- iOS Human Interface Guidelines: Toolbars
- SF Symbols: sun.max, sun.max.fill
- SwiftUI @AppStorage documentation
- UIScreen brightness API documentation

### C. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-06 | serbypau | Initial draft |

---

## 12. Approval

**Product Owner**: ___________________ Date: ___________

**Engineering Lead**: ___________________ Date: ___________

**QA Lead**: ___________________ Date: ___________
