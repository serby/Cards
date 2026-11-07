---
name: simulator-review
description: The standard way to show Paul a change to Card Barcodes in the iOS simulator (rule 11). Use it when a feature, screen or look needs his review, when asked to run, launch or screenshot the app, or to "launch it in the iPhone 17" or "the iPhone SE for testing". It builds, validates, installs and launches the app with the seeded cards and a fixed location, and takes review screenshots into /tmp. It never refreshes the committed App Store screenshots.
---

# Simulator review: show Paul a change

Rule 11 in `AGENTS.md`: anything Paul needs to see is built, tested and run in the simulator and shown to him with screenshots before it is pushed. Commit as you go; push only once he agrees the version ships. Sections 2 and 6 of `docs/DEVELOPMENT.md` hold the detail; this is the procedure.

## Never during review

- **No App Store screenshots.** Do not run `make capture-screenshots` or `make store-screenshots`, and do not touch `screenshots/`, until Paul says the version is ready for the App Store. They are refreshed once, by the release skill, at release. Review screenshots go in `/tmp`.
- **No push.** `main` is what the next version ships from.
- **Leave Paul's uncommitted edits alone.** Check `git status` first; never `git add -A` while he has changes in the tree, and say what you left out.

## 1. Validate

Run the loop: `swiftlint lint`, `make build`, `make test` (plus `make check-release` when `Cards/Development` or `Cards/App/DevelopmentHooks.swift` changed). `make test` takes about 5 minutes. If a UI test times out after hours, the simulator stalled (often while the Mac slept): rerun it before suspecting the code.

## 2. Launch

Paul's test devices are listed once, in `scripts/lib/test-devices.ts` (`docs/DEVELOPMENT.md` section 6, "Test devices"):

- **iPhone 17 simulator**, on the newest installed iOS 27: the default. Use it unless Paul names another device. On this Mac it is "iPhone 17 (Default)".
- **iPhone SE (3rd generation) simulator**, on iOS 27.0: for the small screen, when a layout might not fit or Paul asks for the SE (`DEVICE=se`).
- **Paul's iPhone (2)**: his main phone for checks on a device, with `make device`, when something needs real hardware (the camera, notifications, sync). It falls back to the first connected iPhone, and says so.

These are not the automated tests' simulator (`SIMULATOR_DEVICE`, the iPhone 16 Pro on iOS 18.1); never pass those variables to `make sim`.

```bash
U=$(node scripts/run-in-simulator.ts --dry-run)   # add --device se for the SE; prints the UDID, boots nothing
make sim >| /tmp/cards-sim.log 2>&1; tail -2 /tmp/cards-sim.log   # or make sim DEVICE=se
xcrun simctl privacy $U grant location net.serby.Cards
xcrun simctl location $U set 51.5091,-0.1963   # Notting Hill Gate, where the seeded cards are seen from
xcrun simctl launch --terminate-running-process $U net.serby.Cards
```

`make sim` builds, boots the simulator, opens Device Hub (Xcode 27 has no Simulator.app) and installs and launches the app. If the simulator does not exist yet, it creates it and says so, and the dry run prints no UDID: run `make sim` first, then the dry run again.

- **Seeding:** `-screenshotSeed` adds the six made-up cards from `Cards/Development/ScreenshotSeed.swift` every time it is passed, so pass it once on a fresh install (`xcrun simctl launch --terminate-running-process $U net.serby.Cards -screenshotSeed`) and launch without it afterwards, or the list fills with duplicates. It also fixes the location and hides Apple Maps' businesses.
- **Keep Paul's cards.** He adds his own cards to these simulators while testing. Don't uninstall the app or erase the simulator unless he asks; a reinstall over the running app keeps the store.
- **Stale binary:** if the screen doesn't show the change, terminate the app and install again; `simctl install` over a running app can keep the old one.
- **Other launch options:** `-uiTesting` gives an in-memory store and hides the Development tab (what the UI tests see). Deep links such as `cards://cards/card/<code>` and `cards://cards/new` open screens directly (`xcrun simctl openurl $U <url>`, which shows a confirmation prompt first).

## 3. Screenshot

```bash
mkdir -p /tmp/cards-review
xcrun simctl io $U screenshot /tmp/cards-review/<screen>.png
xcrun simctl ui $U appearance dark    # and back to light afterwards
```

Take each screen the change affects, in light and dark where colour or contrast matters, and at a large Dynamic Type size where layout might break (`xcrun simctl ui $U content_size extra-extra-extra-large`, then `large` to reset). Look at every image yourself with the Read tool before showing it: check names, distances, truncation and contrast.

## 4. Report

Tell Paul in a few lines what changed and how to try it in the simulator, show the screenshots, and list anything you noticed but did not change. Then iterate on his feedback and commit each agreed change (rule 10). When he says the version ships, hand over to the release skill (`.claude/skills/release/SKILL.md`).
