# Cards Project Context

## Build System

This project uses Bazel (via Bazelisk) as its primary build system. The Xcode project is generated from Bazel BUILD files using `rules_xcodeproj`.

### Makefile (preferred for local dev)
A `Makefile` wraps common Bazel commands with the correct simulator flags:

| Command | What it does |
|---------|-------------|
| `make build` | `bazel build //Cards:Cards` |
| `make test` | `bazel test //CardsTests:CardsTests` with `--ios_simulator_device="iPhone 16" --ios_simulator_version=26.0` |
| `make sim` | Builds, boots iPhone 16 simulator, installs and launches the app |

Always use `make test` instead of bare `bazel test` locally — it pins the correct simulator device and OS version to avoid test runner failures.

### Key Commands
- `make build` - Build the app (preferred)
- `make test` - Run unit tests on iPhone 16 / iOS 26.0 (preferred)
- `make sim` - Build and launch in simulator
- `bazel run //:xcodeproj` - Regenerate Xcode project
- `swift package resolve` then `bazel mod tidy` - After changing SPM dependencies

### Bazel Files
| File | Purpose |
|------|---------|
| `.bazelversion` | Pins Bazel version (7.4.1) |
| `MODULE.bazel` | External dependencies (rules_apple, rules_swift, rules_xcodeproj, rules_swift_package_manager) |
| `.bazelrc` | Build settings (disk cache, local performance) |
| `BUILD` | Root: exports Info.plist, xcodeproj target |
| `Cards/BUILD` | swift_library + ios_application |
| `CardsTests/BUILD` | swift_library + ios_unit_test |
| `CardsUITests/BUILD` | swift_library + ios_ui_test |
| `Package.swift` | SPM dependency declarations (consumed by rules_swift_package_manager) |

## CI/CD Integration Points

**WARNING**: These files are interconnected. Changes to one may break others.

### Fastlane Lanes (fastlane/Fastfile)
| Lane | Used By | Purpose |
|------|---------|---------|
| `deploy_alpha` | `.github/workflows/deploy.yml` | Deploy to TestFlight |
| `sim` | Local dev only | Build via Bazel + install on simulator |
| `screenshots` | Manual | Upload screenshots to App Store Connect |
| `metadata` | Manual | Upload metadata to App Store Connect |
| `release` | Manual | Deploy to App Store |

### GitHub Actions Workflows
- `.github/workflows/ci.yml` - Runs on PR/push, installs Bazelisk, calls `bazel build` and `bazel test` directly (no Fastlane)
- `.github/workflows/deploy.yml` - Runs after CI success on main, installs Bazelisk, calls `fastlane deploy_alpha`

### Before Renaming Fastlane Lanes
1. Search for lane name in `.github/workflows/`
2. Update all workflow files that reference the lane
3. Update README.md if it documents the lane

### Before Modifying GitHub Workflows
1. Check if workflow triggers other workflows (`workflow_run`)
2. Verify secret names match what's configured in GitHub

### Before Modifying BUILD Files
1. Run `bazel build //Cards:Cards` to verify the build
2. Run `bazel run //:xcodeproj` to regenerate the Xcode project
3. Open in Xcode to verify schemes still work
