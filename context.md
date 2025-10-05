# Cards App - Development Context

## Project Overview
Cards is a SwiftUI-based iOS application for barcode card management with camera scanning, deep linking, and comprehensive navigation.

## Development Principles

### System Integration Verification
**Always verify complete system integration, not just individual components**

**Mental Model**: Think in terms of **user journeys**, not isolated features
- Entry point → Processing → Final state
- URL scheme → Navigation handling → UI update
- User action → Data flow → UI response

### Architecture Patterns

**Singletons**
- Never use Singletons under any circumstance. Globalism is bad avoid at all costs!

**Navigation Architecture**
- Path-based routing with NavigationStack
- Centralized NavigationManager for state management
- Type-safe route definitions with enums
- Deep linking through URL scheme handling

**State Management**
- SwiftUI @ObservableObject for navigation state
- SwiftData for persistent storage
- Avoid @MainActor isolation in testable components

## Development Checklists

### New Feature Implementation
- [ ] Define clear entry and exit points
- [ ] Create unit tests for logic components
- [ ] Create integration tests for full user flows
- [ ] Verify all connection points are updated
- [ ] Search codebase for old patterns to replace
- [ ] Test end-to-end user journey manually

### Navigation System Changes
- [ ] Update NavigationRoute enum if needed
- [ ] Update NavigationManager for new flows
- [ ] Update all view navigation calls
- [ ] Test deep linking for new routes
- [ ] Verify backstack behavior
- [ ] Update URL scheme documentation

### Testing Strategy
- [ ] Unit tests for individual components
- [ ] Integration tests for component interactions
- [ ] End-to-end tests for complete user flows
- [ ] Manual testing of critical paths
- [ ] Code coverage verification
- [ ] Performance impact assessment

## Verification Loops

### Before Claiming Completion
1. **Code Search**: `grep -r "old_pattern" .` to find remaining usage
2. **Integration Test**: Write test that exercises complete flow
3. **Manual Verification**: Test actual user scenario
4. **Dependency Check**: Verify all connection points updated

### When Introducing New Systems
1. **Inventory existing usage**: Find all places old system is used
2. **Create migration plan**: Document what needs updating
3. **Update incrementally**: Replace usage one component at a time
4. **Deprecate old system**: Mark as deprecated with clear migration path
5. **Verify replacement**: Ensure no old system usage remains

### Testing Validation
1. **Unit tests pass**: Individual components work correctly
2. **Integration tests pass**: Components work together
3. **End-to-end tests pass**: Complete user flows work
4. **Manual testing**: Real user scenarios verified
5. **Performance acceptable**: No significant regressions

## Common Failure Patterns

### AI/Agent Reasoning Failures
- **Assumption without verification**: Claiming integration exists without checking
- **Component-focused thinking**: Testing parts instead of wholes
- **Success bias**: Focusing on making new things work vs ensuring old things are replaced
- **Incomplete migration**: Adding new systems without removing old ones

### Prevention Strategies
- **Always verify assumptions** with actual code inspection
- **Test complete user journeys** from entry to exit
- **Search for old patterns** when introducing new systems
- **Require evidence** for integration claims
- **Challenge success statements** with specific verification steps

## Mental Models

### System Integration Model
```
Entry Point → Processing Layer → State Management → UI Update
     ↓              ↓                ↓              ↓
  Verify         Verify           Verify         Verify
 Connected      Logic Works     State Updates   UI Reflects
```

### Testing Pyramid
```
    E2E Tests (Few, High Value)
         ↑
   Integration Tests (Some)
         ↑
    Unit Tests (Many, Fast)
```

### Change Impact Analysis
```
New Feature → Identify Touch Points → Update Each Point → Verify Integration
```

## Quality Gates

### Code Review Focus
- Are all integration points identified and updated?
- Do tests cover the complete user journey?
- Is old code properly deprecated/removed?
- Are assumptions backed by verification?

### Definition of Done
- [ ] Feature works in isolation
- [ ] Feature integrates with existing system
- [ ] All entry points connect properly
- [ ] Tests cover integration scenarios
- [ ] Old patterns removed/deprecated
- [ ] Documentation updated
- [ ] **FINAL VERIFICATION**: All targets build successfully (run after all changes)
- [ ] **FINAL VERIFICATION**: All tests pass (run after all changes)
