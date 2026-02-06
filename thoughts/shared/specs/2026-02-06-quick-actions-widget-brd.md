# Business Requirements Document: Quick Actions Widget

**Document Version**: 1.0  
**Date**: 2026-02-06  
**Author**: serbypau  
**Status**: Draft  
**Related Research**: `thoughts/shared/research/2026-02-06-barcode-brightness-toggle.md`

---

## Executive Summary

Add iOS Home Screen and Lock Screen widgets that display recently used cards with direct access to barcode views. This reduces friction for frequently accessed cards by eliminating the need to open the app, navigate, and find the card.

**Key Value**: Transform 4-5 taps into a single tap for accessing frequently used cards.

---

## 1. Business Requirements

### 1.1 Problem Statement

**Current State:**
- Users must open app → wait for launch → find card in list → tap to view barcode
- Frequently used cards (gym, coffee shop, grocery store) require same repetitive navigation
- No quick access from iOS Home Screen or Lock Screen

**Pain Points:**
- 4-5 taps and 2-3 seconds to access a barcode
- Friction when hands are full or in a hurry
- App must be found and launched every time
- No integration with iOS ecosystem features

**Business Impact:**
- Reduced app engagement due to friction
- Competitive disadvantage (many card apps have widgets)
- Missed opportunity for iOS platform integration
- Lower user satisfaction for power users

### 1.2 Proposed Solution

Create iOS widgets in three sizes that:
- Display recently used cards with live barcode previews
- Provide direct tap-to-view access to full card detail
- Support both Home Screen and Lock Screen placement
- Auto-update based on card usage patterns
- Respect user privacy with configurable visibility

### 1.3 Success Metrics

**Quantitative:**
- 30%+ of users add widget within first week
- 50%+ reduction in time-to-barcode for widget users
- 20%+ increase in daily active usage
- Widget tap-through rate > 60%

**Qualitative:**
- Positive user feedback on convenience
- App Store reviews mentioning widget feature
- Reduced support requests about "quick access"

### 1.4 Business Value

- **User Experience**: Instant access to frequently used cards
- **Competitive Advantage**: Feature parity with leading card apps
- **Platform Integration**: Better iOS ecosystem integration
- **Retention**: Increased daily touchpoints with app
- **Discoverability**: Widget presence increases app awareness

---

## 2. Functional Requirements

### 2.1 Widget Sizes & Layouts

#### FR-1: Small Widget (2x2)
**Priority**: P0 (Must Have)

Display single most recently used card.

**Layout:**
```
┌─────────────┐
│ Card Name   │
│             │
│  [Barcode]  │
│             │
│ Code: 1234  │
└─────────────┘
```

**Acceptance Criteria:**
- Shows most recently viewed card
- Displays card name (truncated if needed)
- Shows barcode preview (scaled to fit)
- Shows partial code number
- Tapping anywhere opens card detail in app
- Updates when different card is viewed in app

#### FR-2: Medium Widget (4x2)
**Priority**: P0 (Must Have)

Display two most recently used cards side-by-side.

**Layout:**
```
┌─────────────────────────────┐
│ Card 1      │  Card 2       │
│             │               │
│ [Barcode]   │  [Barcode]    │
│             │               │
│ Code: 1234  │  Code: 5678   │
└─────────────────────────────┘
```

**Acceptance Criteria:**
- Shows 2 most recently viewed cards
- Each card is independently tappable
- Cards are ordered by recency (left = most recent)
- Layout adapts gracefully to card name lengths
- Updates when cards are viewed in app

#### FR-3: Large Widget (4x4)
**Priority**: P1 (Should Have)

Display four most recently used cards in 2x2 grid.

**Layout:**
```
┌─────────────────────────────┐
│ Card 1      │  Card 2       │
│ [Barcode]   │  [Barcode]    │
│ Code: 1234  │  Code: 5678   │
├─────────────┼───────────────┤
│ Card 3      │  Card 4       │
│ [Barcode]   │  [Barcode]    │
│ Code: 9012  │  Code: 3456   │
└─────────────────────────────┘
```

**Acceptance Criteria:**
- Shows 4 most recently viewed cards
- Each card is independently tappable
- Cards ordered by recency (top-left = most recent)
- Graceful handling when fewer than 4 cards exist
- Updates when cards are viewed in app

### 2.2 Widget Behavior

#### FR-4: Recent Cards Logic
**Priority**: P0 (Must Have)

Widget displays cards based on recency of viewing.

**Acceptance Criteria:**
- "Recently used" = cards viewed in card detail view
- Timestamp updated when user navigates to CardItemView
- Cards sorted by most recent timestamp descending
- Viewing a card in app immediately updates widget (within 1 second)
- Widget shows placeholder if no cards exist

#### FR-5: Deep Linking
**Priority**: P0 (Must Have)

Tapping a card in widget opens that specific card in the app.

**Acceptance Criteria:**
- Tap opens app to CardItemView for that card
- Uses existing deep link infrastructure (cards://cards/card/{code})
- App launches if not running
- App brings to foreground if backgrounded
- Navigation stack is properly configured
- Works from both Home Screen and Lock Screen

#### FR-6: Widget Updates
**Priority**: P0 (Must Have)

Widget content stays synchronized with app data.

**Acceptance Criteria:**
- Widget updates when card is viewed in app
- Widget updates when card is edited (name/code change)
- Widget updates when card is deleted (removes from widget)
- Updates occur within 1 second of app change
- Widget uses WidgetKit timeline for efficient updates
- No excessive battery drain from updates

### 2.3 Lock Screen Widget

#### FR-7: Lock Screen Support
**Priority**: P1 (Should Have)

Provide Lock Screen widget variants for iOS 16+.

**Widget Types:**
- **Circular**: Shows barcode icon + card count
- **Rectangular**: Shows most recent card name + barcode preview
- **Inline**: Shows "Recent: [Card Name]"

**Acceptance Criteria:**
- Lock Screen widgets available in widget gallery
- Tapping opens app to most recent card
- Respects Lock Screen privacy settings
- Updates with app usage
- Works with Face ID/Touch ID unlock

### 2.4 Privacy & Security

#### FR-8: Privacy Controls
**Priority**: P0 (Must Have)

Users can control widget visibility and content.

**Acceptance Criteria:**
- Setting in app: "Show Cards in Widgets" (default: ON)
- When OFF: Widget shows placeholder "Open app to view cards"
- Lock Screen widgets respect privacy setting
- Sensitive card data not visible when device is locked (optional per-card setting)
- Widget respects iOS system privacy settings

#### FR-9: Empty State Handling
**Priority**: P0 (Must Have)

Widget handles cases with no cards gracefully.

**Acceptance Criteria:**
- No cards: Shows "Add cards in app" message with app icon
- Privacy disabled: Shows "Enable in Settings" message
- Deleted cards: Automatically removed from widget
- All cards deleted: Shows empty state
- Tapping empty state opens app to card list

### 2.5 Visual Design

#### FR-10: Widget Styling
**Priority**: P0 (Must Have)

Widget follows iOS design guidelines and app branding.

**Acceptance Criteria:**
- Supports light and dark mode
- Uses app accent color for branding
- Barcode renders clearly at widget size
- Text is legible at all sizes
- Follows iOS widget design patterns
- Matches app visual style
- Proper padding and spacing

---

## 3. Technical Requirements

### 3.1 Architecture

#### TR-1: Widget Extension Target
**Implementation:**
- Create new Widget Extension target: "CardsWidget"
- Add WidgetKit and SwiftUI frameworks
- Configure app group for data sharing: `group.com.serby.cards`
- Update main app entitlements to include app group
- Update widget entitlements to include app group

#### TR-2: Data Sharing
**Implementation:**
- Configure SwiftData ModelContainer with app group
- Share CardItem data between app and widget
- Use `@AppStorage` with app group suite for settings
- Implement efficient data queries for widget timeline

**Code Pattern:**
```swift
// Shared ModelContainer configuration
let container = try ModelContainer(
    for: CardItem.self,
    configurations: ModelConfiguration(
        groupContainer: .identifier("group.com.serby.cards")
    )
)
```

#### TR-3: Widget Timeline Provider
**Implementation:**
- Create `CardsTimelineProvider` conforming to `TimelineProvider`
- Implement `placeholder(in:)` for widget gallery
- Implement `getSnapshot(in:completion:)` for preview
- Implement `getTimeline(in:completion:)` for widget updates
- Query recent cards from shared SwiftData container
- Generate timeline entries with 15-minute refresh policy

#### TR-4: Widget Views
**Files to Create:**
- `CardsWidget/CardsWidget.swift` - Main widget definition
- `CardsWidget/CardsWidgetView.swift` - Widget UI
- `CardsWidget/SmallCardWidget.swift` - Small widget layout
- `CardsWidget/MediumCardWidget.swift` - Medium widget layout
- `CardsWidget/LargeCardWidget.swift` - Large widget layout
- `CardsWidget/CardWidgetEntry.swift` - Timeline entry model

### 3.2 Recent Cards Tracking

#### TR-5: Usage Tracking
**Implementation:**
- Add `lastViewed: Date?` property to CardItem model
- Update timestamp in CardItemView's `onAppear`
- Create query for recent cards: `sort by lastViewed descending`
- Reload widget timeline after timestamp update

**Code Location:**
- Modify: `Core/Models/CardItem.swift` (add lastViewed property)
- Modify: `Features/CardDetail/Views/CardItemView.swift` (update timestamp)
- Create: `Core/Services/WidgetUpdateService.swift` (trigger widget refresh)

#### TR-6: Widget Refresh
**Implementation:**
- Use `WidgetCenter.shared.reloadTimelines(ofKind:)` after card view
- Implement background refresh with `BGTaskScheduler` (optional)
- Use timeline policy: `.after(Date().addingTimeInterval(900))` (15 min)

### 3.3 Deep Linking

#### TR-7: Widget Deep Links
**Implementation:**
- Use existing deep link infrastructure: `cards://cards/card/{code}`
- Add `widgetURL()` modifier to widget views
- Handle URL in existing `onOpenURL` handler in CardsApp
- Navigate to CardItemView for specific card

**Code Pattern:**
```swift
// In widget view
.widgetURL(URL(string: "cards://cards/card/\(card.code)"))

// Already exists in CardsApp.swift
.onOpenURL { url in
    navigationManager.handleDeepLink(url)
}
```

### 3.4 Lock Screen Widgets (iOS 16+)

#### TR-8: Lock Screen Widget Family
**Implementation:**
- Add `accessoryCircular`, `accessoryRectangular`, `accessoryInline` families
- Create separate views for each Lock Screen widget type
- Use `@available(iOS 16.0, *)` for Lock Screen features
- Implement compact layouts for Lock Screen constraints

---

## 4. Testing Requirements

### 4.1 Unit Tests

#### UT-1: Timeline Provider Tests
**File**: `CardsWidgetTests/TimelineProviderTests.swift` (new)

**Test Cases:**
- [ ] Test placeholder returns valid entry
- [ ] Test snapshot returns most recent card
- [ ] Test timeline queries recent cards correctly
- [ ] Test timeline handles empty card list
- [ ] Test timeline handles deleted cards
- [ ] Test timeline refresh policy is correct (15 min)

#### UT-2: Recent Cards Logic Tests
**File**: `CardsTests/RecentCardsTests.swift` (new)

**Test Cases:**
- [ ] Test lastViewed timestamp updates on card view
- [ ] Test recent cards query returns correct order
- [ ] Test recent cards query limits to N cards
- [ ] Test deleted cards don't appear in recent list
- [ ] Test edited cards maintain recent status

#### UT-3: Data Sharing Tests
**File**: `CardsTests/DataSharingTests.swift` (new)

**Test Cases:**
- [ ] Test app group container is accessible
- [ ] Test SwiftData container shares data correctly
- [ ] Test widget can read card data from shared container
- [ ] Test @AppStorage syncs between app and widget

### 4.2 Widget Tests

#### WT-1: Widget Rendering Tests
**File**: `CardsWidgetTests/WidgetViewTests.swift` (new)

**Test Cases:**
- [ ] Test small widget renders single card
- [ ] Test medium widget renders two cards
- [ ] Test large widget renders four cards
- [ ] Test widget handles long card names (truncation)
- [ ] Test widget renders barcodes correctly
- [ ] Test widget supports light and dark mode
- [ ] Test empty state renders correctly

#### WT-2: Widget Interaction Tests
**Test Cases:**
- [ ] Test tapping widget card opens correct deep link
- [ ] Test deep link URL format is correct
- [ ] Test widget updates after card is viewed in app
- [ ] Test widget updates after card is edited
- [ ] Test widget removes deleted cards

### 4.3 Manual Testing Checklist

#### MT-1: Widget Installation
- [ ] Widget appears in widget gallery
- [ ] All three sizes are available
- [ ] Widget can be added to Home Screen
- [ ] Widget can be added to Lock Screen (iOS 16+)
- [ ] Multiple widgets can be added
- [ ] Widget can be removed

#### MT-2: Widget Content
- [ ] Small widget shows most recent card
- [ ] Medium widget shows 2 most recent cards
- [ ] Large widget shows 4 most recent cards
- [ ] Card names display correctly
- [ ] Barcodes render clearly
- [ ] Code numbers are visible
- [ ] Empty state shows when no cards exist

#### MT-3: Widget Updates
- [ ] Widget updates when card is viewed in app
- [ ] Widget updates when card name is edited
- [ ] Widget updates when card code is edited
- [ ] Widget updates when card is deleted
- [ ] Update happens within 1-2 seconds
- [ ] Widget doesn't update excessively (battery test)

#### MT-4: Deep Linking
- [ ] Tapping widget card opens app
- [ ] App navigates to correct card detail view
- [ ] Deep link works when app is closed
- [ ] Deep link works when app is backgrounded
- [ ] Deep link works from Lock Screen
- [ ] Navigation stack is correct after deep link

#### MT-5: Visual Design
- [ ] Widget looks good in light mode
- [ ] Widget looks good in dark mode
- [ ] Widget matches app visual style
- [ ] Barcodes are legible at widget size
- [ ] Text is readable at all sizes
- [ ] Layout adapts to different card name lengths
- [ ] Widget looks good on different device sizes (iPhone SE to Pro Max)

#### MT-6: Privacy & Security
- [ ] Privacy setting in app works correctly
- [ ] Widget shows placeholder when privacy is disabled
- [ ] Lock Screen widgets respect privacy settings
- [ ] Sensitive cards can be hidden from widgets (if implemented)
- [ ] Widget respects iOS system privacy settings

#### MT-7: Edge Cases
- [ ] Widget handles 0 cards gracefully
- [ ] Widget handles 1 card (medium/large widgets)
- [ ] Widget handles 2 cards (large widget)
- [ ] Widget handles very long card names
- [ ] Widget handles special characters in card names
- [ ] Widget handles all barcode types correctly
- [ ] Widget handles app uninstall/reinstall
- [ ] Widget handles data corruption gracefully

### 4.4 Performance Testing

#### PT-1: Performance Metrics
- [ ] Widget timeline generation < 100ms
- [ ] Widget update after card view < 1 second
- [ ] Widget doesn't cause excessive battery drain
- [ ] Widget doesn't cause excessive memory usage
- [ ] Widget renders smoothly (no lag or jank)
- [ ] App launch from widget < 1 second

---

## 5. Implementation Phases

### Phase 1: Widget Extension Setup (4-6 hours)
**Tasks:**
- Create Widget Extension target
- Configure app group entitlements
- Set up shared SwiftData container
- Create basic widget structure (placeholder)
- Test data sharing between app and widget

**Success Criteria:**
- Widget extension builds successfully
- App group is configured correctly
- Widget can read CardItem data from shared container
- Basic placeholder widget appears in gallery

### Phase 2: Recent Cards Tracking (2-3 hours)
**Tasks:**
- Add `lastViewed` property to CardItem model
- Update timestamp in CardItemView
- Create recent cards query
- Implement widget timeline provider
- Test recent cards logic

**Success Criteria:**
- Viewing card updates lastViewed timestamp
- Recent cards query returns correct order
- Widget timeline provider queries recent cards
- Timeline updates on schedule

### Phase 3: Widget UI Implementation (6-8 hours)
**Tasks:**
- Implement small widget layout
- Implement medium widget layout
- Implement large widget layout
- Add barcode rendering to widgets
- Implement light/dark mode support
- Add empty state handling

**Success Criteria:**
- All three widget sizes render correctly
- Barcodes display clearly
- Widgets support light and dark mode
- Empty states work correctly

### Phase 4: Deep Linking (2-3 hours)
**Tasks:**
- Add widgetURL to widget views
- Test deep link navigation
- Handle edge cases (app closed, backgrounded)
- Test navigation stack correctness

**Success Criteria:**
- Tapping widget opens correct card
- Deep links work in all app states
- Navigation is smooth and correct

### Phase 5: Lock Screen Widgets (3-4 hours)
**Tasks:**
- Implement circular Lock Screen widget
- Implement rectangular Lock Screen widget
- Implement inline Lock Screen widget
- Test Lock Screen widget behavior

**Success Criteria:**
- Lock Screen widgets available in gallery
- Lock Screen widgets render correctly
- Lock Screen widgets respect privacy settings

### Phase 6: Privacy & Polish (2-3 hours)
**Tasks:**
- Add privacy setting in app
- Implement privacy placeholder in widget
- Add widget refresh optimization
- Polish visual design
- Add accessibility support

**Success Criteria:**
- Privacy setting works correctly
- Widget respects privacy preference
- Widget updates efficiently
- Accessibility labels are correct

### Phase 7: Testing & Bug Fixes (4-6 hours)
**Tasks:**
- Write unit tests
- Write widget tests
- Perform manual testing
- Fix bugs found during testing
- Performance testing and optimization

**Success Criteria:**
- All automated tests pass
- All manual test cases pass
- No critical bugs
- Performance is acceptable

**Total Estimated Effort**: 23-33 hours

---

## 6. User Experience Specifications

### 6.1 User Flows

**Primary Flow: Add Widget**
1. User long-presses Home Screen
2. Taps "+" to add widget
3. Searches or scrolls to "Cards" app
4. Selects widget size (small/medium/large)
5. Taps "Add Widget"
6. Widget appears showing recent cards
7. User taps widget to open card in app

**Alternative Flow: Lock Screen Widget**
1. User long-presses Lock Screen
2. Taps "Customize"
3. Selects widget area
4. Searches for "Cards" app
5. Selects Lock Screen widget type
6. Widget appears on Lock Screen
7. User unlocks and taps widget to open card

### 6.2 Widget Gallery Preview

**Small Widget Preview:**
- Shows app icon + "Recent Card"
- Displays sample barcode
- Text: "Quick access to your most used card"

**Medium Widget Preview:**
- Shows app icon + "Recent Cards"
- Displays two sample barcodes
- Text: "Quick access to your 2 most used cards"

**Large Widget Preview:**
- Shows app icon + "Recent Cards"
- Displays four sample barcodes in grid
- Text: "Quick access to your 4 most used cards"

---

## 7. Out of Scope

The following items are explicitly **NOT** included in this BRD:

- Widget configuration (user-selected cards) - future enhancement
- Interactive widgets (iOS 17+) - future enhancement
- Widget analytics/tracking - future enhancement
- Custom widget refresh intervals - uses system default
- Widget for iPad - focus on iPhone first
- Widget for Apple Watch - separate feature
- Siri shortcuts integration - separate feature
- Widget themes or customization - uses app theme

---

## 8. Risks & Mitigations

### Risk 1: Battery Drain from Widget Updates
**Risk**: Frequent widget updates could drain battery.

**Mitigation**:
- Use WidgetKit timeline with 15-minute refresh policy
- Only update widget when card is actually viewed
- Use efficient SwiftData queries
- Test battery impact during development

**Likelihood**: Medium  
**Impact**: Medium

### Risk 2: Data Sharing Complexity
**Risk**: App group and SwiftData sharing could be complex to implement.

**Mitigation**:
- Follow Apple's documentation for app groups
- Test data sharing early in development
- Use existing SwiftData patterns from app
- Have fallback to UserDefaults if needed

**Likelihood**: Low  
**Impact**: High

### Risk 3: Widget Size Constraints
**Risk**: Barcodes might not be legible at small widget sizes.

**Mitigation**:
- Test barcode rendering at all widget sizes
- Use appropriate barcode scaling
- Consider showing barcode icon instead of actual barcode for very small sizes
- Provide clear visual feedback that tapping opens full barcode

**Likelihood**: Medium  
**Impact**: Low

### Risk 4: Privacy Concerns
**Risk**: Users might not want cards visible on Home Screen.

**Mitigation**:
- Provide privacy setting to disable widget content
- Default to showing cards (opt-out, not opt-in)
- Clear messaging about privacy controls
- Lock Screen widgets respect device lock state

**Likelihood**: Low  
**Impact**: Medium

---

## 9. Success Criteria

### Definition of Done

This feature is considered complete when:

1. **Functional Requirements Met**:
   - [ ] Small, medium, and large widgets implemented
   - [ ] Widgets display recent cards correctly
   - [ ] Deep linking works from all widget sizes
   - [ ] Widget updates when cards are viewed/edited/deleted
   - [ ] Lock Screen widgets implemented (iOS 16+)
   - [ ] Privacy controls work correctly
   - [ ] Empty states handled gracefully

2. **Testing Complete**:
   - [ ] All unit tests pass
   - [ ] All widget tests pass
   - [ ] Manual testing checklist completed
   - [ ] Performance testing completed
   - [ ] No critical bugs

3. **Quality Standards Met**:
   - [ ] Widgets follow iOS design guidelines
   - [ ] Barcodes are legible at all sizes
   - [ ] Light and dark mode support
   - [ ] Accessibility labels implemented
   - [ ] No excessive battery drain
   - [ ] Widget updates efficiently

4. **Documentation Complete**:
   - [ ] Widget implementation documented
   - [ ] App group configuration documented
   - [ ] Privacy settings documented

---

## 10. Appendix

### A. Related Documents
- Research: `thoughts/shared/research/2026-02-06-barcode-brightness-toggle.md`
- Implementation Plan: TBD

### B. Technical References
- Apple WidgetKit Documentation
- App Groups Programming Guide
- SwiftData Shared Container Guide
- Widget Design Guidelines (HIG)

### C. Design Assets
- Widget preview images (to be created)
- Lock Screen widget mockups (to be created)

### D. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-06 | serbypau | Initial draft |

---

## 11. Approval

**Product Owner**: ___________________ Date: ___________

**Engineering Lead**: ___________________ Date: ___________

**QA Lead**: ___________________ Date: ___________
