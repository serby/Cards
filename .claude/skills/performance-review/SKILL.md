---
name: performance-review
description: The standard way to measure and review how fast Card Barcodes launches and opens a card from a link. Use it when asked to time the app, trace or profile it, check launch or deep-link speed, look for performance improvements, or check whether a change made the app faster or slower. It runs scripts/trace-performance.ts in the script's own simulator and reviews the report it writes. It changes no app code unless Paul asks.
---

# Performance review: measure, then find improvements

`node scripts/trace-performance.ts` (or `make trace-performance`) builds the app, traces it in the iPhone 17 (Cards performance) simulator and writes `build/performance/<date-time>/report.md`, with `summary.json` and every trace beside it; `build/performance/latest` points at the newest. This skill runs it and reviews what it finds.

## Never during a review

- **No code changes unless Paul asks.** A review reports and recommends. Another session may be working in the tree at the same time, so leave every file alone until he says which improvement to make.
- **Never touch anyone else's build or simulator.** The script builds into `build/performance/dd`, not Xcode's build location, and only ever uses its own simulator, which it may uninstall and refill freely. Don't point it at another.
- **No claims without numbers.** Every finding cites the report: the measure, its median and spread, and the functions or libraries behind it.

## 1. Run it

- **Default:** `node scripts/trace-performance.ts`: a release build, 5 runs each of a cold launch, a cold deep link to a card and a deep link from the background, about 6 minutes after the build.
- **A quiet Mac:** builds, test runs and other simulators slow the runs they overlap, by as much as three times. Run it when nothing else is building or testing, and check the *Mac load* column in *Every run*.
- **Steadier numbers:** `--runs 10`. Medians move by a few milliseconds between runs of the script; a change smaller than the spread (min to max) is noise.
- **One scenario:** `--scenario deep-link` (repeat for more): `launch`, `deep-link`, `warm-deep-link`.
- **Again without building:** `--skip-build` reuses the last build in `build/performance`.
- **Before and after a change:** run once on the commit before it, then with the change and `--baseline build/performance/<date-time>` from the first run. The report adds the baseline's medians and the change. Like for like only: the same configuration, simulator and number of runs.
- **A debug build:** `--configuration Debug`, which is slower and spends its time differently; use release for anything about speed.
- **Another card:** `--card "Joe's Market"` (any of the screenshot cards; the default is the last in the list).

If a run fails twice, the report says why in its notes; the commonest cause is xctrace failing to attach, which another run fixes.

## 2. Read the report

- **Results.** Milliseconds from the start of each run: the first frame and when the app was responsive, and for the links when the card screen appeared and was on screen. *How it was measured* says exactly what each is.
- **Where the main thread's time goes.** For the start to the first frame, and for the first frame (or the link) to the card on screen:
  - *App function, with what it called*: inclusive time, so nested functions overlap. Look here for which of the app's own steps are expensive.
  - *Innermost app function*: whose work each millisecond was, including the system code it called. These add up to the main thread's total, so they rank where to look.
  - *Library the time was in*: SwiftData and CoreData, SwiftUI, dyld, UIKit and so on. A big share in one library points at the kind of work.
- **Core Data.** Fetches and saves, and how much of each was on the main thread.
- **Every run.** One row per run, with the Mac's load and its trace. A run far from the others, especially with a higher load, is noise; open its trace before trusting the medians, and rerun if several are like it.

## 3. Find improvements

Look for, in this order:

1. **Work before the first frame that the first screen does not need.** Anything in `CardsApp.init()` or the first `body` that could wait until after the first frame, run off the main thread, or happen lazily: building the `ModelContainer` and `Schema`, CloudKit set-up, location, notifications, widget snapshots, the review prompt.
2. **The gap between the first frame and the card on a cold deep link.** The first frame shows the list, then the card is pushed. Whether the link could be handled before the first frame (so the card is the first frame) or the push made cheaper.
3. **Main-thread Core Data.** Fetches and saves on the main thread, especially ones that run twice, or fetch every card to find one.
4. **Repeated SwiftUI work.** The same `body` high in the inclusive list on every run, or layout and text measurement dominating the libraries.

For each finding give: what it is and where (file and function), the evidence (medians, functions, libraries), a proposed change, the expected saving, and the risk, ranked by saving for the effort. Then stop and ask Paul which to make.

## 4. Check a change

After an agreed change: run with `--baseline` on the report from before it, and quote the medians and the change. A simulator runs on the Mac's processor, so confirm anything worth shipping on the phone too: `make device`, then Instruments' App Launch template (`xcrun xctrace record --template 'App Launch' --device <udid> --launch -- net.serby.Cards`), which on a phone also breaks the launch into its phases.

## Looking deeper

- `open build/performance/latest/traces/<scenario>-<n>.trace` opens a run in Instruments.
- `xcrun xctrace export --input <trace> --toc` lists its tables; *Looking deeper* in the report gives the `--xpath` for the samples, the signposts and the Core Data tables. `scripts/lib/xctrace.ts` reads them (`readTable`, `framesOf`), and `scripts/lib/performance.ts` turns them into the report.
- What the simulator cannot show: the SwiftUI instrument and the App Launch template's phases record nothing in the simulator, so view-body counts and the launch phases need the phone.
