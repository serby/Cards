// Tests for what a performance trace shows and the report on a set of them
// (scripts/lib/performance.ts). Run with: node --test scripts/performance.test.ts

import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
    analyseRun,
    breakdown,
    findMilestones,
    type PerformanceSummary,
    renderReport,
    type RunResult,
    runStart,
    type Sample,
    samplesFrom,
    type Signpost,
    signpostsFrom,
    spansFrom,
    stats,
    summarise,
    type TraceData,
} from "./lib/performance.ts";

const app = (name: string) => ({ name, binary: "Cards" });
const system = (name: string, binary = "SwiftUICore") => ({ name, binary });

function sample(timeMs: number, frames: Sample["frames"], mainThread = true): Sample {
    return { timeMs, weightMs: 1, mainThread, frames };
}

function signpost(timeMs: number, name: string, event = "End", subsystem = "com.apple.app_launch_measurement"): Signpost {
    return { timeMs, event, name, subsystem, mainThread: true };
}

const commit = (timeMs: number) => signpost(timeMs, "Commit", "End", "com.apple.coreanimation");

/// A cold deep link as the simulator records it: dyld reports images to
/// Instruments until 2000 ms, the initialisers start at 2980, the list's
/// first frame is at 3430, the card screen saves at 3500 and its commit ends
/// at 3530. A background save (CloudKit's) comes earlier.
function coldDeepLink(): TraceData {
    return {
        samples: [
            sample(600, [system("dyld4::prepareSim", "dyld")]),
            sample(1999, [system("notifyMonitorOfImageListChangesSim", "dyld")]),
            sample(2980, [system("_os_feature_table", "libsystem_kernel.dylib"), system("libSystem_initializer", "libSystem.B.dylib")]),
            sample(3000, [system("Schema.init", "SwiftData"), app("CardStore.schema.unsafeMutableAddressor"), app("CardsApp.init()"), app("main")]),
            sample(3001, [system("Schema.init", "SwiftData"), app("CardsApp.init()"), app("main")]),
            sample(3200, [system("objc_msgSend", "libobjc.A.dylib")]),
            sample(3300, [system("render", "QuartzCore")], false),
            sample(3480, [system("body", "SwiftUICore"), app("CardDetailView.body.getter"), app("CardDetailView.body.getter")]),
        ],
        signposts: [
            signpost(3430, "ApplicationFirstFramePresentation"),
            commit(3440),
            commit(3530),
            signpost(3560, "ApplicationFirstFramePresentationResponsive"),
        ],
        saves: [
            { startMs: 3100, durationMs: 0.3, mainThread: false },
            { startMs: 3500, durationMs: 0.5, mainThread: true },
        ],
        fetches: [{ startMs: 3050, durationMs: 2, mainThread: true, entity: "CardItem" }],
    };
}

describe("runStart", () => {
    test("starts a cold run when the initialisers do, leaving dyld's work for the trace out", () => {
        assert.equal(runStart(coldDeepLink(), "deep-link", 0), 2980);
    });

    test("has no cold start when no sample caught an initialiser, rather than count dyld's second", () => {
        const data = { ...coldDeepLink(), samples: [sample(10, [system("start", "dyld")]), sample(20, [app("main")])] };
        assert.equal(runStart(data, "launch", 0), undefined);
    });

    test("starts a warm run at the main thread's first sample after the link", () => {
        const data = { ...coldDeepLink(), samples: [sample(100, [app("main")]), sample(150, [app("main")], false), sample(160, [app("main")])] };
        assert.equal(runStart(data, "warm-deep-link", 120), 160);
    });

    test("has no warm start when the main thread never ran after the link", () => {
        assert.equal(runStart({ ...coldDeepLink(), samples: [sample(100, [app("main")])] }, "warm-deep-link", 120), undefined);
    });
});

describe("findMilestones", () => {
    test("finds the first frame, responsiveness and the card from the main-thread save and the next commit", () => {
        assert.deepEqual(findMilestones(coldDeepLink(), "deep-link", 2980), {
            firstFrameMs: 3430,
            responsiveMs: 3560,
            cardAppearedMs: 3500,
            cardOnScreenMs: 3530,
        });
    });

    test("looks for no card in a plain launch", () => {
        assert.deepEqual(findMilestones(coldDeepLink(), "launch", 2980), { firstFrameMs: 3430, responsiveMs: 3560 });
    });

    test("uses the activation signposts for a warm run", () => {
        const data = {
            ...coldDeepLink(),
            signposts: [signpost(3430, "ApplicationFirstFramePresentation"), signpost(3450, "ApplicationActivationFirstFramePresentation"), commit(3530)],
        };
        assert.deepEqual(findMilestones(data, "warm-deep-link", 3000), { firstFrameMs: 3450, cardAppearedMs: 3500, cardOnScreenMs: 3530 });
    });

    test("takes the card's commit from the main thread only", () => {
        const data = { ...coldDeepLink(), signposts: [{ ...commit(3510), mainThread: false }, commit(3530)] };
        assert.equal(findMilestones(data, "deep-link", 2980).cardOnScreenMs, 3530);
    });

    test("ignores milestones from before the start", () => {
        assert.deepEqual(findMilestones(coldDeepLink(), "deep-link", 3540), { responsiveMs: 3560 });
    });
});

describe("breakdown", () => {
    const launch = breakdown(coldDeepLink().samples, 2980, 3430, "Start to first frame");

    test("counts the main thread's samples in the stretch only", () => {
        assert.equal(launch.mainThreadMs, 4);
        assert.equal(launch.durationMs, 450);
    });

    test("counts an app function once per sample, with what it called", () => {
        assert.deepEqual(launch.appFunctions.slice(0, 3), [
            { name: "CardsApp.init()", ms: 2 },
            { name: "main", ms: 2 },
            { name: "CardStore.schema.unsafeMutableAddressor", ms: 1 },
        ]);
    });

    test("gives each sample to its innermost app function, or to none", () => {
        assert.deepEqual(launch.innermostAppFunctions, [
            { name: "(no app code)", ms: 2 },
            { name: "CardsApp.init()", ms: 1 },
            { name: "CardStore.schema.unsafeMutableAddressor", ms: 1 },
        ]);
    });

    test("gives each sample to the library of its innermost frame", () => {
        assert.deepEqual(launch.libraries, [
            { name: "SwiftData", ms: 2 },
            { name: "libobjc.A.dylib", ms: 1 },
            { name: "libsystem_kernel.dylib", ms: 1 },
        ]);
    });

    test("counts a recursive app function once", () => {
        const card = breakdown(coldDeepLink().samples, 3430, 3530, "First frame to card on screen");
        assert.deepEqual(card.appFunctions, [{ name: "CardDetailView.body.getter", ms: 1 }]);
    });
});

describe("analyseRun", () => {
    test("measures a cold deep link from the start, with both stretches and Core Data", () => {
        const result = analyseRun(coldDeepLink(), { scenario: "deep-link", run: 1, trace: "traces/deep-link-1.trace", notBeforeMs: 0 });
        assert.deepEqual(result.milestones, { firstFrameMs: 450, responsiveMs: 580, cardAppearedMs: 520, cardOnScreenMs: 550 });
        assert.equal(result.launch?.label, "Start to first frame");
        assert.equal(result.card?.label, "First frame to card on screen");
        assert.equal(result.card?.durationMs, 100);
        assert.deepEqual(result.coreData, { fetches: 1, fetchMs: 2, mainThreadFetchMs: 2, saves: 2, saveMs: 0.8, mainThreadSaveMs: 0.5 });
        assert.deepEqual(result.notes, []);
    });

    test("says what is missing", () => {
        const data = { ...coldDeepLink(), signposts: [], saves: [] };
        assert.deepEqual(analyseRun(data, { scenario: "deep-link", run: 2, trace: "t", notBeforeMs: 0 }).notes, [
            "No first-frame signpost.",
            "The card screen never appeared (no main-thread Core Data save).",
        ]);
    });

    test("leaves out a cold run with no sample in an initialiser", () => {
        const data = { ...coldDeepLink(), samples: [sample(10, [system("start", "dyld")])] };
        const result = analyseRun(data, { scenario: "launch", run: 1, trace: "t", notBeforeMs: 0 });
        assert.deepEqual(result.milestones, {});
        assert.deepEqual(result.notes, ["No sample caught the process's initialisers, so the run has no start and is left out."]);
    });

    test("labels a cold card stretch from the start when the card came first", () => {
        const data = { ...coldDeepLink(), signposts: [commit(3530), signpost(3600, "ApplicationFirstFramePresentation")] };
        assert.equal(analyseRun(data, { scenario: "deep-link", run: 1, trace: "t", notBeforeMs: 0 }).card?.label, "Start to card on screen");
    });

    test("says when a warm run's app never ran", () => {
        const result = analyseRun({ ...coldDeepLink(), samples: [] }, { scenario: "warm-deep-link", run: 1, trace: "t", notBeforeMs: 5000 });
        assert.deepEqual(result.milestones, {});
        assert.deepEqual(result.notes, ["The app's main thread never ran after the link was sent."]);
    });
});

describe("stats", () => {
    test("gives the median of an odd and an even number of runs", () => {
        assert.equal(stats([3, 1, 2])?.median, 2);
        assert.equal(stats([4, 1, 3, 2])?.median, 2.5);
    });

    test("gives the mean, minimum and maximum", () => {
        assert.deepEqual(stats([10, 30, 20]), { median: 20, mean: 20, min: 10, max: 30, runs: 3 });
    });

    test("gives nothing for no runs", () => {
        assert.equal(stats([]), undefined);
    });
});

function runResult(run: number, firstFrameMs: number): RunResult {
    return {
        scenario: "launch",
        run,
        trace: `traces/launch-${run}.trace`,
        milestones: { firstFrameMs },
        launch: { label: "Start to first frame", durationMs: firstFrameMs, mainThreadMs: firstFrameMs / 2, appFunctions: [{ name: "main", ms: run }], innermostAppFunctions: [], libraries: [{ name: "SwiftUI", ms: 10 }] },
        macLoad: 2.5,
        notes: [],
    };
}

describe("summarise", () => {
    test("averages the stretches over the runs and spreads the milestones", () => {
        const summary = summarise([runResult(1, 400), runResult(2, 500), runResult(3, 450)], "launch");
        assert.equal(summary.runs, 3);
        assert.equal(summary.metrics.firstFrameMs?.median, 450);
        assert.equal(summary.metrics.cardOnScreenMs, undefined);
        assert.equal(summary.launch?.durationMs, 450);
        assert.equal(summary.launch?.runs, 3);
        assert.deepEqual(summary.launch?.appFunctions, [{ name: "main", ms: 2 }]);
        assert.deepEqual(summary.launch?.libraries, [{ name: "SwiftUI", ms: 10 }]);
    });

    test("averages only the stretches most runs measured", () => {
        const odd = { ...runResult(3, 900), launch: { ...runResult(3, 900).launch!, label: "Link to first frame" } };
        const summary = summarise([runResult(1, 400), runResult(2, 500), odd], "launch");
        assert.equal(summary.launch?.label, "Start to first frame");
        assert.equal(summary.launch?.runs, 2);
        assert.equal(summary.launch?.durationMs, 450);
    });

    test("keeps the top fifteen libraries and puts the rest under (other), so they add up", () => {
        const libraries = Array.from({ length: 20 }, (_, index) => ({ name: `lib${String(index).padStart(2, "0")}`, ms: 20 - index }));
        const run = { ...runResult(1, 400), launch: { ...runResult(1, 400).launch!, mainThreadMs: 210, libraries } };
        const listed = summarise([run], "launch").launch?.libraries ?? [];
        assert.equal(listed.length, 16);
        assert.deepEqual(listed.at(-1), { name: "(other)", ms: 15 });
        assert.equal(listed.reduce((total, item) => total + item.ms, 0), 210);
    });
});

function summaryWith(firstFrames: number[], overrides: Partial<PerformanceSummary> = {}): PerformanceSummary {
    const runs = firstFrames.map((value, index) => runResult(index + 1, value));
    return {
        format: 1,
        createdAt: "2026-11-08T13:00:00.000Z",
        commit: "ab05459",
        uncommittedChanges: false,
        builtAt: "2026-11-08T12:50:00.000Z",
        reusedBuild: false,
        configuration: "Release",
        xcode: "27.1",
        mac: { cpu: "Apple M4 Max", cores: 14 },
        simulator: { name: "iPhone 17 (Cards performance)", os: "27.0", udid: "UDID" },
        card: { name: "Nordic Nest Home", code: "2093847561024" },
        runsPerScenario: firstFrames.length,
        settleSeconds: 6,
        scenarios: [summarise(runs, "launch")],
        runs,
        ...overrides,
    };
}

describe("renderReport", () => {
    test("gives the medians, the main thread's time and every run", () => {
        const report = renderReport(summaryWith([400, 500, 450]));
        assert.match(report, /\| Cold launch \| First frame \| 450\.0 \| 400\.0 \| 500\.0 \| 3 \|/);
        assert.match(report, /#### Start to first frame/);
        assert.match(report, /\| `main` \| 2\.0 \| 1% \|/);
        assert.match(report, /\| Cold launch \| 3 \| 450\.0 \| – \| – \| – \| 2\.5 \| `traces\/launch-3\.trace` \|/);
        assert.match(report, /on Apple M4 Max with 14 cores/);
        assert.match(report, /cards:\/\/cards\/card\/2093847561024/);
        assert.doesNotMatch(report, /Baseline/);
    });

    test("compares the medians with a baseline's", () => {
        const report = renderReport(summaryWith([400, 500, 450]), summaryWith([500, 500, 500], { commit: "e0733b0" }));
        assert.match(report, /\*\*Baseline:\*\* 2026-11-08T13:00:00\.000Z, Release from `e0733b0`/);
        assert.match(report, /\| Cold launch \| First frame \| 450\.0 \| 400\.0 \| 500\.0 \| 3 \| 500\.0 \| -50\.0 ms \(-10%\) \|/);
        assert.doesNotMatch(report, /not like for like/);
    });

    test("warns when the baseline is another configuration", () => {
        const report = renderReport(summaryWith([400]), summaryWith([300], { configuration: "Debug" }));
        assert.match(report, /The baseline is not like for like:\*\* a Debug build \(now a Release build\)\./);
    });

    test("lists every way the baseline was measured differently", () => {
        const report = renderReport(summaryWith([400, 450]), summaryWith([300], { xcode: "26.3", settleSeconds: 3 }));
        assert.match(report, /not like for like:\*\* Xcode 26\.3 \(now Xcode 27\.1\); 1 run of each scenario \(now 2 runs of each scenario\); recorded for 3 s \(now recorded for 6 s\)\./);
    });
});

describe("reading the exports", () => {
    const thread = `<thread id="9" fmt="Main Thread (0x1) (Card Barcodes, pid: 7)"><tid id="10" fmt="0x1">1</tid></thread>`;

    test("reads signposts", () => {
        const xml = `<trace-query-result><node xpath='x'><schema name="os-signpost"><col><mnemonic>time</mnemonic></col><col><mnemonic>thread</mnemonic></col><col><mnemonic>event-type</mnemonic></col><col><mnemonic>name</mnemonic></col><col><mnemonic>subsystem</mnemonic></col></schema>
<row><event-time id="1" fmt="00:03.561">3561607000</event-time>${thread}<event-type id="2" fmt="End">End</event-type><string id="3" fmt="ApplicationFirstFramePresentation">ApplicationFirstFramePresentation</string><subsystem id="4" fmt="com.apple.app_launch_measurement">com.apple.app_launch_measurement</subsystem></row>
</node></trace-query-result>`;
        assert.deepEqual(signpostsFrom(xml), [{ timeMs: 3561.607, event: "End", name: "ApplicationFirstFramePresentation", subsystem: "com.apple.app_launch_measurement", mainThread: true }]);
    });

    test("reads samples with their weight and frames", () => {
        const xml = `<trace-query-result><node xpath='x'><schema name="time-profile"><col><mnemonic>time</mnemonic></col><col><mnemonic>thread</mnemonic></col><col><mnemonic>weight</mnemonic></col><col><mnemonic>stack</mnemonic></col></schema>
<row><sample-time id="1" fmt="00:02.981">2981763500</sample-time>${thread}<weight id="2" fmt="1.00 ms">1000000</weight><tagged-backtrace id="3"><frame id="4" name="libSystem_initializer" addr="0x1"><binary id="5" name="libSystem.B.dylib"/></frame></tagged-backtrace></row>
</node></trace-query-result>`;
        assert.deepEqual(samplesFrom(xml), [{ timeMs: 2981.7635, weightMs: 1, mainThread: true, frames: [{ name: "libSystem_initializer", binary: "libSystem.B.dylib" }] }]);
    });

    test("reads Core Data fetches with their entity", () => {
        const xml = `<trace-query-result><node xpath='x'><schema name="core-data-fetch"><col><mnemonic>start</mnemonic></col><col><mnemonic>duration</mnemonic></col><col><mnemonic>fetch-entity</mnemonic></col><col><mnemonic>thread</mnemonic></col></schema>
<row><start-time id="1" fmt="00:03.211">3211719000</start-time><duration id="2" fmt="2.09 ms">2090000</duration><string id="3" fmt="CardItem">CardItem</string>${thread}</row>
</node></trace-query-result>`;
        assert.deepEqual(spansFrom(xml), [{ startMs: 3211.719, durationMs: 2.09, mainThread: true, entity: "CardItem" }]);
    });
});
