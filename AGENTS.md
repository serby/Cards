# Working on Cards

Read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) before changing anything. Its numbered rules are the contract for every change; in short:

1. **Development code never ships.** Storybook, previews, sample data, stand-ins and test seeds live in `Cards/Development` (excluded from Release). Production code reaches them only through `Cards/App/DevelopmentHooks.swift`, whose functions hold the `#if DEBUG`; no `#if DEBUG` anywhere else. Verify with `make check-release`.
2. **Views in `Cards/UI` are pure:** view state, actions and injected effects in, no store or device access.
3. **Impure work lives in `Cards/Features` connectors and `Cards/Core/Services`.**
4. **Every view has a story, and every parameter has a knob.** Screen stories use `galleryLayout: .oneAtATime`.
5. **Follow the visual style guide, [docs/STYLE.md](docs/STYLE.md).** Corners nest (inner radius = outer radius − inset), text on a card colour sits on a white panel or in the colour's ink over its readable gradient, colours show at full strength, and contrast is tested. Never lower a contrast threshold.
6. **Models stay CloudKit- and export-compatible:** defaults on every property, optional DTO fields, legacy-import tests.
7. **Swift 6, no warnings, clean lint.**
8. **Accessibility is part of done.**
9. **Test logic, persistence and promises;** refresh the screenshots, raw and store, when a change to the screens they show is agreed to ship.
10. **One concern per commit, straight on `main`:** no branches or pull requests (one contributor). Conventional prefix, body says why. A push to `main` runs CI and then uploads to TestFlight, so run the validation loop first.
11. **Shape features in the simulator before they ship.** Build, test and run anything Paul needs to see in the simulator, and show him screenshots. Commit, but push only once he agrees it ships as a new version, with the screenshots refreshed in the same push. Fixes, tooling and docs that change nothing on screen can be pushed when the loop passes.

Validation loop after every change: `swiftlint lint`, `make build`, `make test`, plus `make check-release` when touching `Cards/Development` or the hooks.
