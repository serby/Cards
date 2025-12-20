# Swift Coding Preferences

## Core Principles
- **DRY** (Don't Repeat Yourself) - Eliminate code duplication
- **KISS** (Keep It Simple, Stupid) - Favor simplicity over complexity
- **SOLID** - Follow SOLID design principles

## Modern Swift Practices

### Concurrency
- ✅ Use `async/await` and `Task` for asynchronous operations
- ✅ Use `@MainActor` for UI updates
- ❌ Avoid `DispatchQueue.async` unless absolutely necessary
- ❌ Avoid completion handlers when async/await is available

### SwiftUI
- ✅ **Prefer SwiftUI over UIKit** - Only use UIKit when absolutely necessary with no SwiftUI alternative
- ✅ Use latest SwiftUI APIs and modifiers
- ✅ Prefer declarative syntax
- ✅ Use `@State`, `@Binding`, `@ObservedObject`, `@StateObject` appropriately
- ✅ Use `Task` for async work in SwiftUI views
- ❌ Avoid UIKit unless required (e.g., AVCaptureSession, specific UIKit-only features)

### Code Style
- ✅ Minimal, focused implementations
- ✅ Clear, descriptive naming
- ✅ Avoid verbose or unnecessary code
- ✅ Use Swift's modern features (property wrappers, result builders, etc.)

### Error Handling
- ✅ Use `throws` and `try/catch` for error handling
- ✅ Use `Result` type when appropriate
- ❌ Avoid force unwrapping (`!`) unless absolutely safe

### Memory Management
- ✅ Use `weak` and `unowned` to prevent retain cycles
- ✅ Use `[weak self]` in closures when capturing self

### Git Commits
- ✅ Use Conventional Commits format: `<type>(<scope>): <description>`
- ✅ Types: `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`
- ✅ Include body with bullet points for multiple changes

## Update Instructions
**IMPORTANT**: This file should be updated whenever new coding preferences or patterns are discovered during development. Add new sections or examples as they emerge from actual code reviews and implementations.

## Recent Learnings
- Prefer `Task { await }` over `DispatchQueue.global().async` for background work
- Use `static func dismantleUIViewController` in `UIViewControllerRepresentable` for proper cleanup

### API Availability Checks
- ✅ **Always use `#available` for iOS version checks** - Provides compile-time safety
- ✅ Create availability-aware View extensions for version-specific modifiers
- ❌ **Never use `ProcessInfo.processInfo.operatingSystemVersion` for API availability** - No compile-time safety, can crash on older OS versions

```swift
// ✅ Correct - Compile-time safe availability check
extension View {
    @ViewBuilder
    func tabBarMinimizeBehaviorIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollUp)
        } else {
            self
        }
    }
}

// ❌ Wrong - Runtime check with no compile-time safety
.if(ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26) { view in
    view.tabBarMinimizeBehavior(.onScrollUp) // Will fail to compile or crash
}
```
