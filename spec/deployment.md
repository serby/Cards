# Deployment

How changes are checked, released and published: the GitHub workflows in `.github/workflows/` and the local commands that match them. How to run each one is in [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md).

### DEPLOY-1: Check every change to the app

As the app's maintainer, I want every change to the app checked on each device and iOS it supports, so that nothing broken reaches a release.

- CI (`ci.yml`) runs on a push to any branch, and on a pull request, that changes the app: `Cards/`, `CardsWidget/`, `CardsTests/`, `CardsUITests/`, `Cards.xcodeproj/`, `.xcode-version`, `.swiftlint.yml`, `.swiftlint-version`, `changelog.json` or `ci.yml` itself. A change to anything else, such as the docs, the spec, the website, `metadata/`, `screenshots/`, `scripts/` or `.claude/`, starts no run. A newer push cancels the run of an older one.
- It checks that the app is valid: SwiftLint passes with the version in `.swiftlint-version` and the rules in `.swiftlint.yml`, failing on warnings as well as errors (`--strict`); every shipped language has every string, with matching placeholders and plural forms (`scripts/check-strings.ts`); and `changelog.json`, which the app shows in Settings > What's New, is valid, starts with the app's version and matches the files made from it (`scripts/check-changelog.ts`).
- It checks that the app builds and passes every test on each device and iOS in the test runs (`testRuns`, `scripts/lib/test-devices.ts`), a job each, with two Xcodes. With the Xcode in `.xcode-version` (27.1), on the `xcode-27` image: the unit tests on the iPhone 17 on iOS 27.0, and the UI tests on the iPhone 17 and the iPad mini (A17 Pro) on iOS 26.5. With Xcode 26.3 (the run's `ciXcode`): the UI tests on the iPhone 17 on iOS 26.5 on the `macos-26` image, and on the iPhone 16 on iOS 18.5 on the `macos-15` image. Each job builds the app and its tests with its Xcode, downloads its iOS runtime from Apple when the runner lacks it, and runs every test of its suite (`scripts/run-tests.ts --run <key>`). A test that fails is run once more; one that fails twice fails the job.
- The versions are written down once: the jobs come from `scripts/print-test-runs.ts`, which reads the same list as `make test-all`, so a device or iOS changes in one place.
- Every job runs to the end even when another fails, and a failing test job uploads its result bundle.
- It does not check the App Store images, the metadata or the release build, and captures no screenshots: those are release checks (DEPLOY-3).

**Since:** In preparation for 1.4
**Where:** `.github/workflows/ci.yml`, `scripts/lib/test-devices.ts`, `scripts/print-test-runs.ts`, `scripts/run-tests.ts`, `scripts/select-xcode.ts`, `scripts/check-strings.ts`, `scripts/check-changelog.ts`, `.swiftlint-version`
**Notes:** The Xcode 26.3 runs check the app still builds and works with Xcode 26, so code newer than its SDK (iOS 26.2) needs a compile-time guard as well as `if #available`. No iPhone 17 runs iOS 18, so that run uses the iPhone 16. Neither Xcode 27 nor Xcode 26.6 can download an iOS 18 runtime ("not available for download"), and GitHub's `macos-15` image is the only one with iOS 18 (18.5 and 18.6, in [its readme](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md)); its newest Xcode is 26.3. Xcode 26's Swift compiler crashes on a method passed as a SwiftUI `Binding` setter (`set: edit` in `LocationPickerView.swift`, 8 November 2026), so setters are closures. Runtimes are pinned by version, as xcodebuild takes no build numbers, so CI's iOS 26.5 can be a release candidate (23F73) where a Mac has the release (23F77).

### DEPLOY-2: Test the scripts when they change

As the app's maintainer, I want the scripts that build, test, release and publish the app tested when they change, so that a broken script is found before it is needed.

- `scripts.yml` runs on a push or pull request that changes `scripts/` or `scripts.yml`, and on nothing else. It runs every script test (`node --test scripts/*.test.ts`).
- A change to the scripts starts no other workflow, and the other workflows' triggers name no script.

**Since:** In preparation for 1.4
**Where:** `.github/workflows/scripts.yml`, `scripts/*.test.ts`

### DEPLOY-3: Release a version

As the app's maintainer, I want a version tag to build, check and submit the app, so that releasing is one step that cannot ship something unchecked.

- `release.yml` runs on a pushed `v*` tag, or by hand. Before anything is signed, built for the App Store or uploaded, it checks that the App Store text in `metadata/` fits App Store Connect's limits (`scripts/check-metadata.ts`), that every App Store image the listing names is present, at its size and with no alpha channel (`scripts/check-store-images.ts`), and that the release build has no development code in it (`scripts/check-release-build.ts`). Any failure stops it.
- It then installs signing, stamps a build number, archives, signs and uploads the app, and on a tag attaches the build to the version, sets What's New and submits it for review (`scripts/release-version.ts`). Run by hand, it uploads without submitting.
- It builds with the Xcode in `.xcode-version`.

**Since:** In preparation for 1.4
**Where:** `.github/workflows/release.yml`, `scripts/release-version.ts`, `scripts/check-metadata.ts`, `scripts/check-store-images.ts`, `scripts/check-release-build.ts`

### DEPLOY-4: Update the App Store listing

As the app's maintainer, I want to update the App Store listing from the repository, so that the text and images on the product page are the ones committed.

- `app-store-listing.yml` runs only by hand. With prepare version and a version number it gives the editable version that number, or creates it, then uploads the text in `metadata/`, the images in `screenshots/store/` and each locale's creative asset. A dry run says what would change and changes nothing. It uploads and attaches no builds.

**Since:** In preparation for 1.4
**Where:** `.github/workflows/app-store-listing.yml`, `scripts/prepare-app-store-version.ts`, `scripts/upload-metadata.ts`, `scripts/upload-screenshots.ts`, `scripts/upload-creative-assets.ts`

### DEPLOY-5: Publish the website

As the app's maintainer, I want the website rebuilt from the app's own sources when they change, so that it always says what the App Store listing and the app say.

- `website.yml` runs on a push to `main` that changes what the site is built from: `Website/`, `metadata/`, `changelog.json`, `screenshots/store/`, the app's string catalogue, colours or project file, or `website.yml`, or by hand. Changes to the scripts do not trigger it (DEPLOY-2).
- While an App Store image is missing it deploys nothing and says so in a notice, without failing. Otherwise it builds the site (`scripts/build-website.ts`), which stops if a source is broken, and deploys it to Cloudflare Pages (`scripts/deploy-website.ts`). One deploy runs at a time, in push order.

**Since:** In preparation for 1.4
**Where:** `.github/workflows/website.yml`, `scripts/build-website.ts`, `scripts/deploy-website.ts`

### DEPLOY-6: Run the same checks before pushing

As the app's maintainer, I want to run CI's checks on my Mac with the same versions, so that CI only confirms what I already know.

- `swiftlint lint` uses the version in `.swiftlint-version` (0.62.2) and the same rules. `make test-all` builds once and runs every test run CI runs, on the same devices and iOS versions; `make test` runs the unit tests and the iPhone 17 UI run. Each run takes under six minutes on Paul's MacBook Pro.
- Local builds use the Xcode in `.xcode-version`, and so do CI's Xcode 27.1 jobs. A Mac runs every test run with that Xcode, so `make test-all` skips the Xcode 26.3 run on the iPhone 17 on iOS 26.5, which would repeat the Xcode 27.1 one, and runs the iOS 18 run on the newest iOS 18 it has (the run's `localOs`), 18.1 on Paul's.

**Since:** In preparation for 1.4
**Where:** `Makefile`, `scripts/run-tests.ts`, `scripts/lib/test-devices.ts`, `.swiftlint-version`, `.xcode-version`
