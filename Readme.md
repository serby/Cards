# Cards

A barcode wallet for iOS. Store loyalty cards, scan their barcodes with the camera, and show them at full brightness at the till.

- **Any barcode:** Code 128, Code 39, Code 93, EAN-8, EAN-13, UPC-E, QR, Aztec and PDF417, scanned with pinch to zoom or typed in.
- **Colours:** each card takes a colour from a palette tested for readable text, shown on the card and as a tint in the list.
- **Locations:** pin any number of places to a card on the map, or by postcode. The list and card show how far away the nearest is, and a notification reminds you when you arrive.
- **Sync and export:** cards sync through iCloud and export to JSON.

Built with SwiftUI, SwiftData and CloudKit as a plain Xcode project, for iOS 18 and later.

## Quick start

```bash
open Cards.xcodeproj   # or:
make build             # build for the simulator
make test              # unit and UI tests
make sim               # build, boot a simulator, install and launch
```

Needs Xcode 27.1, the version pinned in `.xcode-version` that CI also uses, SwiftLint, and Node 24 for the release check.

## Developing

**[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)** is the guide to working on Cards: set-up, the everyday validation loop, project layout, the rules every change follows, recipes for common jobs, the simulator, signing and iCloud, releasing and troubleshooting. [AGENTS.md](AGENTS.md) is the short version for coding agents.

The rule people most often trip over: development code (the Storybook, previews, sample data, test seeds) lives in `Cards/Development`, which release builds leave out, and production code reaches it only through `Cards/App/DevelopmentHooks.swift`. `make check-release` proves nothing slipped through.

## Repository

| Path | What |
|------|------|
| `Cards/` | The app: `App`, `Core`, `UI`, `Scanner`, `Features`, and `Development` (never shipped) |
| `CardsTests/`, `CardsUITests/` | Unit tests (Swift Testing) and UI and screenshot tests (XCTest) |
| `screenshots/`, `metadata/` | App Store screenshots (also the UI test references) and store listing |
| `scripts/` | Build, release, screenshot, icon and release-check scripts |
| `DesignAssets/` | App icon master (`Icon.svg`) |
| `Website/` | The marketing site |
| `docs/` | Development guide, CI and deployment set-up |
