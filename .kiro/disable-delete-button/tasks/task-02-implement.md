# Task 02 — Add `.disabled(cards.isEmpty)` to SettingsView.swift

**Status:** done  
**Completed:** 2026-03-15  
**File:** `Cards/Features/Settings/Views/SettingsView.swift`

## Change
Add `.disabled(cards.isEmpty)` immediately after the closing brace of the `Button("Delete All Cards", role: .destructive)` block (~line 72).

## Before
```swift
Button("Delete All Cards", role: .destructive) {
    showDeleteConfirmation = true
}
```

## After
```swift
Button("Delete All Cards", role: .destructive) {
    showDeleteConfirmation = true
}
.disabled(cards.isEmpty)
```

## Notes
- `cards` is already available via `@Query private var cards: [CardItem]`
- No other changes required
