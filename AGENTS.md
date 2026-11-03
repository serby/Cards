# Working on Cards

Read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) before changing anything. Its numbered rules are the contract for every change; in short:

1. **Development code never ships.** Storybook, previews, sample data, stand-ins and test seeds live in `Cards/Development` (excluded from Release). Production code reaches them only through `Cards/App/DevelopmentHooks.swift`, whose functions hold the `#if DEBUG`; no `#if DEBUG` anywhere else. Verify with `make check-release`.
2. **Views in `Cards/UI` are pure:** view state, actions and injected effects in, no store or device access.
3. **Impure work lives in `Cards/Features` connectors and `Cards/Core/Services`.**
4. **Every view has a story, and every parameter has a knob.** Screen stories use `galleryLayout: .oneAtATime`.
5. **Card colours come from the tested palette.** Never lower a contrast threshold.
6. **Models stay CloudKit- and export-compatible:** defaults on every property, optional DTO fields, legacy-import tests.
7. **Swift 6, no warnings, clean lint.**
8. **Accessibility is part of done.**
9. **Test logic, persistence and promises;** refresh screenshot references when the screens they show change.
10. **One concern per commit, straight on `main`:** no branches or pull requests (one contributor). Conventional prefix, body says why. A push to `main` runs CI and then uploads to TestFlight, so run the validation loop first.

Validation loop after every change: `swiftlint lint`, `make build`, `make test`, plus `make check-release` when touching `Cards/Development` or the hooks.
