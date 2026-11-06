# Working on Cards

Read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) before changing anything. Its numbered rules are the contract for every change; in short:

1. **Development code never ships.** Storybook, sample data, stand-ins and test seeds live in `Cards/Development` (excluded from Release); previews sit at the bottom of their view's file inside `#if DEBUG`. Production code reaches them only through `Cards/App/DevelopmentHooks.swift`, whose functions hold the `#if DEBUG`; the only other `#if DEBUG` is the one wrapping a view's previews at the bottom of its file. Verify with `make check-release`.
2. **Views in `Cards/UI` are pure:** view state, actions and injected effects in, no store or device access.
3. **Impure work lives in `Cards/Features` connectors and `Cards/Core/Services`.**
4. **Every view has a story and a preview, and every parameter has a knob.** Screen stories use `galleryLayout: .oneAtATime`. Every main view and connector has a few useful `#Preview`s at the bottom of its own file, inside `#if DEBUG`.
5. **Follow the visual style guide, [docs/STYLE.md](docs/STYLE.md).** Corners nest (inner radius = outer radius − inset), text on a card colour sits on a white panel or in the colour's ink over its readable gradient, colours show at full strength, and contrast is tested. Never lower a contrast threshold.
6. **Models stay CloudKit- and export-compatible:** defaults on every property, optional DTO fields, legacy-import tests.
7. **Swift 6, no warnings, clean lint.**
8. **Accessibility is part of done.**
9. **Test logic, persistence and promises;** refresh the screenshots, raw and store, when a change to the screens they show is agreed to ship.
10. **One concern per commit, straight on `main`:** no branches or pull requests (one contributor). Conventional prefix, body says why. A push to `main` runs CI, so run the validation loop first.
11. **Shape features in the simulator before they ship.** Build, test and run anything Paul needs to see in the simulator, and show him screenshots. Commit, but push only once he agrees it ships as a new version, with the screenshots refreshed in the same push. Fixes, tooling and docs that change nothing on screen can be pushed when the loop passes.
12. **Mark changes with the release skill, [.claude/skills/release/SKILL.md](.claude/skills/release/SKILL.md).** `changelog.json` records every change people notice and generates `CHANGELOG.md`, the App Store's What's New and Settings > What's New. The same skill releases a version.
13. **Keep [spec/](spec/README.md) current.** It describes the whole app as user stories. A change that adds or alters behaviour updates the matching stories in the same commit.
14. **Scripts are TypeScript, named for what they do.** All code is Swift or TypeScript: no Python, shell or JavaScript scripts. Run scripts with `node scripts/<verb>-<thing>.ts`; shared code lives in `scripts/lib/`; Xcode tools go through `scripts/lib/xcode.ts`; unused scripts are deleted.
15. **Small parts, injected dependencies, no global state.** No `static var` state or singletons of our own. Every side effect (notifications, location, geocoding, clipboard, URLs, files) goes through a small client struct with a `.live` value, injected through the environment and wired once in `CardsApp`. Case-less enums only for pure code. One job per type; simplest thing that works; every fact in one place; logic tested through stand-in clients.
16. **Words follow [docs/LANGUAGE.md](docs/LANGUAGE.md).** British English, plain voice, and made-up businesses (Joe's Market, Local Roast Coffee) in every example: never a real brand in the store listing, screenshots, placeholders, sample data, tests or docs.

Validation loop after every change: `swiftlint lint`, `make build`, `make test`, plus `make check-release` when touching `Cards/Development` or the hooks.
