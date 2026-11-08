// What a performance trace of the app shows, and the report on a set of them,
// for scripts/trace-performance.ts.
//
// Each run is one trace of the app, attached before it starts doing anything:
// a cold launch, a cold deep link to a card, or a deep link while the app is in
// the background. From the trace it finds when the app started running, when
// iOS showed its first frame and found it responsive (UIKit's own launch
// signposts, which Apple's launch metrics use), when the card screen appeared
// (its onAppear saves the card's last-viewed date, the first Core Data save on
// the main thread) and the Core Animation commit that put it on screen. Then it
// says where the main thread spent that time, by the app's own functions and
// by library, and what Core Data did.
//
// Usage: import { analyseRun, renderReport, summarise, ... } from "./lib/performance.ts";

import { type Frame, framesOf, readTable, type Row } from "./xctrace.ts";

/// What a run measures.
export const scenarios = ["launch", "deep-link", "warm-deep-link"] as const;
export type Scenario = (typeof scenarios)[number];

export const scenarioTitles: Record<Scenario, string> = {
    launch: "Cold launch",
    "deep-link": "Cold deep link to a card",
    "warm-deep-link": "Deep link to a card from the background",
};

export const scenarioDescriptions: Record<Scenario, string> = {
    launch: "The app is not running; it opens on the cards list.",
    "deep-link": "The app is not running; a cards:// link opens it on a card.",
    "warm-deep-link": "The app is in the background; a cards:// link brings it forward on a card.",
};

/// Whether a scenario starts the app from scratch.
export function isCold(scenario: Scenario): boolean {
    return scenario !== "warm-deep-link";
}

/// Whether a scenario opens a card.
export function opensCard(scenario: Scenario): boolean {
    return scenario !== "launch";
}

/// The binaries the app's own code is in: the app, and its debug dylib in a
/// debug build.
const appBinaries = new Set(["Cards", "Cards.debug.dylib"]);

/// A signpost the app emitted, or UIKit, Core Animation or SwiftUI in it.
export interface Signpost {
    /// Milliseconds since the trace started.
    timeMs: number;
    /// "Begin", "End" or "Event".
    event: string;
    name: string;
    subsystem: string;
    mainThread: boolean;
}

/// A Time Profiler sample of one of the app's threads.
export interface Sample {
    timeMs: number;
    weightMs: number;
    mainThread: boolean;
    /// Innermost first.
    frames: Frame[];
}

/// A Core Data fetch or save.
export interface Span {
    startMs: number;
    durationMs: number;
    mainThread: boolean;
    /// The entity a fetch was for.
    entity?: string;
}

/// What a run's trace holds, as this analysis needs it.
export interface TraceData {
    signposts: Signpost[];
    samples: Sample[];
    saves: Span[];
    fetches: Span[];
}

function milliseconds(nanoseconds: string | undefined): number {
    return Number(nanoseconds ?? Number.NaN) / 1_000_000;
}

function onMainThread(row: Row): boolean {
    return row.thread?.shown.startsWith("Main Thread") ?? false;
}

/// The signposts in an export of the trace's os-signpost table.
export function signpostsFrom(xml: string): Signpost[] {
    return readTable(xml).rows
        .map((row) => ({
            timeMs: milliseconds(row.time?.value),
            event: row["event-type"]?.shown ?? "",
            name: row.name?.shown ?? "",
            subsystem: row.subsystem?.shown ?? "",
            mainThread: onMainThread(row),
        }))
        .filter((signpost) => Number.isFinite(signpost.timeMs))
        .sort((a, b) => a.timeMs - b.timeMs);
}

/// The samples in an export of the trace's time-profile table.
export function samplesFrom(xml: string): Sample[] {
    const table = readTable(xml);
    return table.rows
        .map((row) => ({
            timeMs: milliseconds(row.time?.value),
            weightMs: milliseconds(row.weight?.value) || 1,
            mainThread: onMainThread(row),
            frames: framesOf(row.stack ?? row.backtrace, table),
        }))
        .filter((sample) => Number.isFinite(sample.timeMs))
        .sort((a, b) => a.timeMs - b.timeMs);
}

/// The fetches or saves in an export of the core-data-fetch or core-data-save table.
export function spansFrom(xml: string): Span[] {
    return readTable(xml).rows
        .map((row) => {
            const span: Span = { startMs: milliseconds(row.start?.value), durationMs: milliseconds(row.duration?.value), mainThread: onMainThread(row) };
            const entity = row["fetch-entity"]?.shown;
            return entity ? { ...span, entity } : span;
        })
        .filter((span) => Number.isFinite(span.startMs))
        .sort((a, b) => a.startMs - b.startMs);
}

/// The moments a run measures, in milliseconds from when the app started
/// running (a cold run) or started handling the link (a warm one).
export interface Milestones {
    /// UIKit's ApplicationFirstFramePresentation ended: iOS showed the first
    /// frame. For a warm run, ApplicationActivationFirstFramePresentation.
    firstFrameMs?: number;
    /// ...FirstFramePresentationResponsive ended: the app answered input.
    responsiveMs?: number;
    /// The card screen's onAppear saved the card: the first main-thread Core
    /// Data save.
    cardAppearedMs?: number;
    /// The end of the first Core Animation commit after that: the card on screen.
    cardOnScreenMs?: number;
}

export const metricLabels: Record<keyof Milestones, string> = {
    firstFrameMs: "First frame",
    responsiveMs: "Responsive",
    cardAppearedMs: "Card screen appears",
    cardOnScreenMs: "Card on screen",
};

export const metricKeys = Object.keys(metricLabels) as (keyof Milestones)[];

/// Milliseconds spent under a name: a function or a library.
export interface Weighted {
    name: string;
    ms: number;
}

/// Where the main thread spent a stretch of a run.
export interface Breakdown {
    /// What the stretch is, such as "Start to first frame".
    label: string;
    /// How long the stretch was.
    durationMs: number;
    /// Main-thread time sampled in it (the thread was running).
    mainThreadMs: number;
    /// The app's functions on the stack, each counted once per sample:
    /// time spent in them and in everything they called.
    appFunctions: Weighted[];
    /// The innermost of the app's functions on the stack: whose work the time
    /// was, including system code it called. "(no app code)" when there was none.
    innermostAppFunctions: Weighted[];
    /// The library the innermost frame was in: where the time actually went.
    libraries: Weighted[];
    /// For an average, how many runs it is over. A run's own lists are
    /// complete; an average keeps the top 15 and, for the two that add up
    /// to the main thread's time, "(other)" for the rest.
    runs?: number;
}

/// What Core Data did in a run, from the start to the last milestone.
export interface CoreDataActivity {
    fetches: number;
    fetchMs: number;
    mainThreadFetchMs: number;
    saves: number;
    saveMs: number;
    mainThreadSaveMs: number;
}

/// One run of a scenario.
export interface RunResult {
    scenario: Scenario;
    run: number;
    /// The trace, relative to the report's folder.
    trace: string;
    milestones: Milestones;
    /// From the start to the first frame.
    launch?: Breakdown;
    /// From the first frame (a cold deep link) or the start (a warm one) to the card on screen.
    card?: Breakdown;
    coreData?: CoreDataActivity;
    /// The Mac's load average over the minute before the run: a run with a
    /// much higher load than the others shared the Mac with other work.
    macLoad?: number;
    /// What went wrong or looked odd.
    notes: string[];
}

const noAppCode = "(no app code)";
const unknownLibrary = "(unknown)";
const listLength = 15;

/// Where the main thread spent [fromMs, toMs).
export function breakdown(samples: readonly Sample[], fromMs: number, toMs: number, label: string): Breakdown {
    const app = new Map<string, number>();
    const innermost = new Map<string, number>();
    const libraries = new Map<string, number>();
    let mainThreadMs = 0;
    const add = (map: Map<string, number>, name: string, ms: number) => map.set(name, (map.get(name) ?? 0) + ms);
    for (const sample of samples) {
        if (!sample.mainThread || sample.timeMs < fromMs || sample.timeMs >= toMs) continue;
        mainThreadMs += sample.weightMs;
        const appFrames = sample.frames.filter((frame) => frame.binary !== undefined && appBinaries.has(frame.binary));
        for (const name of new Set(appFrames.map((frame) => frame.name))) add(app, name, sample.weightMs);
        add(innermost, appFrames[0]?.name ?? noAppCode, sample.weightMs);
        add(libraries, sample.frames[0]?.binary ?? unknownLibrary, sample.weightMs);
    }
    return {
        label,
        durationMs: toMs - fromMs,
        mainThreadMs,
        appFunctions: top(app, Number.POSITIVE_INFINITY),
        innermostAppFunctions: top(innermost, Number.POSITIVE_INFINITY),
        libraries: top(libraries, Number.POSITIVE_INFINITY),
    };
}

function top(map: Map<string, number>, limit = listLength): Weighted[] {
    return [...map].map(([name, ms]) => ({ name, ms })).sort((a, b) => b.ms - a.ms || a.name.localeCompare(b.name)).slice(0, limit);
}

const otherName = "(other)";

/// The top of a list that adds up to `total`, with "(other)" for the rest.
function topWithOther(map: Map<string, number>, total: number): Weighted[] {
    const listed = top(map);
    const rest = total - listed.reduce((sum, item) => sum + item.ms, 0);
    return map.size > listed.length && rest > 0.05 ? [...listed, { name: otherName, ms: rest }] : listed;
}

/// Frames that run as the process's initialisers start, after dyld has loaded
/// its images: libSystem's first, then every image's, the app's included.
const initialiserFrames = /^libSystem_initializer$|findAndRunAllInitializers|runAllInitializers/;

/// Where a run starts, in trace time. A cold run starts when the process's
/// initialisers do: dyld's loading before that is left out, because with
/// Instruments attached dyld in the simulator spends over a second reporting
/// every image it loads, then waits: time Instruments adds. Without a sample
/// in an initialiser a cold run has no start, rather than one that counts
/// that second. A warm run starts when its main thread first runs at or after
/// `notBeforeMs`, when the link was sent. Undefined when the trace has no
/// such sample.
export function runStart(data: TraceData, scenario: Scenario, notBeforeMs: number): number | undefined {
    if (isCold(scenario)) return data.samples.find((sample) => sample.frames.some((frame) => initialiserFrames.test(frame.name)))?.timeMs;
    return data.samples.find((sample) => sample.mainThread && sample.timeMs >= notBeforeMs)?.timeMs;
}

function signpostEnd(data: TraceData, name: string, afterMs: number): number | undefined {
    return data.signposts.find((signpost) => signpost.event === "End" && signpost.name === name && signpost.timeMs >= afterMs)?.timeMs;
}

/// The run's milestones, in absolute trace time.
export function findMilestones(data: TraceData, scenario: Scenario, startMs: number): Milestones {
    const prefix = isCold(scenario) ? "Application" : "ApplicationActivation";
    const milestones: Milestones = {};
    const firstFrame = signpostEnd(data, `${prefix}FirstFramePresentation`, startMs);
    const responsive = signpostEnd(data, `${prefix}FirstFramePresentationResponsive`, startMs);
    if (firstFrame !== undefined) milestones.firstFrameMs = firstFrame;
    if (responsive !== undefined) milestones.responsiveMs = responsive;
    if (opensCard(scenario)) {
        const appeared = data.saves.find((save) => save.mainThread && save.startMs >= startMs)?.startMs;
        if (appeared !== undefined) {
            milestones.cardAppearedMs = appeared;
            const commit = data.signposts.find((signpost) => signpost.event === "End" && signpost.name === "Commit" && signpost.subsystem === "com.apple.coreanimation" && signpost.mainThread && signpost.timeMs >= appeared);
            if (commit) milestones.cardOnScreenMs = commit.timeMs;
        }
    }
    return milestones;
}

function relative(milestones: Milestones, startMs: number): Milestones {
    const result: Milestones = {};
    for (const key of metricKeys) {
        const value = milestones[key];
        if (value !== undefined) result[key] = value - startMs;
    }
    return result;
}

function coreDataActivity(data: TraceData, fromMs: number, toMs: number): CoreDataActivity {
    const within = (span: Span) => span.startMs >= fromMs && span.startMs <= toMs;
    const fetches = data.fetches.filter(within);
    const saves = data.saves.filter(within);
    const sum = (spans: Span[]) => spans.reduce((total, span) => total + span.durationMs, 0);
    return {
        fetches: fetches.length,
        fetchMs: sum(fetches),
        mainThreadFetchMs: sum(fetches.filter((span) => span.mainThread)),
        saves: saves.length,
        saveMs: sum(saves),
        mainThreadSaveMs: sum(saves.filter((span) => span.mainThread)),
    };
}

interface RunDetails {
    scenario: Scenario;
    run: number;
    trace: string;
    /// For a warm run, when the link was sent, in trace time.
    notBeforeMs: number;
}

/// Measures one run from its trace.
export function analyseRun(data: TraceData, details: RunDetails): RunResult {
    const { scenario, run, trace } = details;
    const result: RunResult = { scenario, run, trace, milestones: {}, notes: [] };
    const startMs = runStart(data, scenario, details.notBeforeMs);
    if (startMs === undefined) {
        const why = !isCold(scenario)
            ? "The app's main thread never ran after the link was sent."
            : data.samples.length === 0
                ? "The trace has no samples of the app."
                : "No sample caught the process's initialisers, so the run has no start and is left out.";
        result.notes.push(why);
        return result;
    }
    const absolute = findMilestones(data, scenario, startMs);
    result.milestones = relative(absolute, startMs);
    if (absolute.firstFrameMs === undefined) result.notes.push("No first-frame signpost.");
    if (opensCard(scenario) && absolute.cardAppearedMs === undefined) result.notes.push("The card screen never appeared (no main-thread Core Data save).");
    if (absolute.cardAppearedMs !== undefined && absolute.cardOnScreenMs === undefined) result.notes.push("No Core Animation commit after the card screen appeared.");

    if (absolute.firstFrameMs !== undefined) {
        result.launch = breakdown(data.samples, startMs, absolute.firstFrameMs, isCold(scenario) ? "Start to first frame" : "Link to first frame");
    }
    if (absolute.cardOnScreenMs !== undefined) {
        const afterFirstFrame = isCold(scenario) && absolute.firstFrameMs !== undefined && absolute.firstFrameMs < absolute.cardOnScreenMs;
        const from = afterFirstFrame && absolute.firstFrameMs !== undefined ? absolute.firstFrameMs : startMs;
        const label = afterFirstFrame ? "First frame to card on screen" : isCold(scenario) ? "Start to card on screen" : "Link to card on screen";
        result.card = breakdown(data.samples, from, absolute.cardOnScreenMs, label);
    }
    const ends = metricKeys.map((key) => absolute[key]).filter((value): value is number => value !== undefined);
    if (ends.length > 0) result.coreData = coreDataActivity(data, startMs, Math.max(...ends));
    return result;
}

/// The spread of a measure over a scenario's runs.
export interface Stats {
    median: number;
    mean: number;
    min: number;
    max: number;
    /// How many runs measured it.
    runs: number;
}

export function stats(values: readonly number[]): Stats | undefined {
    if (values.length === 0) return undefined;
    const sorted = [...values].sort((a, b) => a - b);
    const middle = Math.floor(sorted.length / 2);
    const median = sorted.length % 2 === 1 ? sorted[middle] ?? 0 : ((sorted[middle - 1] ?? 0) + (sorted[middle] ?? 0)) / 2;
    return {
        median,
        mean: sorted.reduce((total, value) => total + value, 0) / sorted.length,
        min: sorted[0] ?? 0,
        max: sorted.at(-1) ?? 0,
        runs: sorted.length,
    };
}

/// A scenario over its runs.
export interface ScenarioSummary {
    scenario: Scenario;
    runs: number;
    metrics: Partial<Record<keyof Milestones, Stats>>;
    /// The runs' breakdowns, averaged per run.
    launch?: Breakdown;
    card?: Breakdown;
    coreData?: CoreDataActivity;
}

/// The average of the runs' breakdowns that measure the same stretch, the
/// most common one when they differ (as when a run's card came before its
/// first frame), so no average mixes two stretches.
function averageBreakdowns(all: readonly Breakdown[]): Breakdown | undefined {
    const counts = new Map<string, number>();
    for (const item of all) counts.set(item.label, (counts.get(item.label) ?? 0) + 1);
    const label = [...counts].sort((a, b) => b[1] - a[1])[0]?.[0];
    const breakdowns = all.filter((item) => item.label === label);
    if (label === undefined || breakdowns.length === 0) return undefined;
    const count = breakdowns.length;
    const sum = (lists: Weighted[][]) => {
        const map = new Map<string, number>();
        for (const list of lists) for (const { name, ms } of list) map.set(name, (map.get(name) ?? 0) + ms / count);
        return map;
    };
    const mainThreadMs = breakdowns.reduce((total, item) => total + item.mainThreadMs, 0) / count;
    return {
        label,
        durationMs: breakdowns.reduce((total, item) => total + item.durationMs, 0) / count,
        mainThreadMs,
        appFunctions: top(sum(breakdowns.map((item) => item.appFunctions))),
        innermostAppFunctions: topWithOther(sum(breakdowns.map((item) => item.innermostAppFunctions)), mainThreadMs),
        libraries: topWithOther(sum(breakdowns.map((item) => item.libraries)), mainThreadMs),
        runs: count,
    };
}

function averageCoreData(activities: readonly CoreDataActivity[]): CoreDataActivity | undefined {
    if (activities.length === 0) return undefined;
    const mean = (key: keyof CoreDataActivity) => activities.reduce((total, activity) => total + activity[key], 0) / activities.length;
    return {
        fetches: mean("fetches"),
        fetchMs: mean("fetchMs"),
        mainThreadFetchMs: mean("mainThreadFetchMs"),
        saves: mean("saves"),
        saveMs: mean("saveMs"),
        mainThreadSaveMs: mean("mainThreadSaveMs"),
    };
}

/// Summarises a scenario's runs.
export function summarise(results: readonly RunResult[], scenario: Scenario): ScenarioSummary {
    const runs = results.filter((result) => result.scenario === scenario);
    const metrics: ScenarioSummary["metrics"] = {};
    for (const key of metricKeys) {
        const spread = stats(runs.map((run) => run.milestones[key]).filter((value): value is number => value !== undefined));
        if (spread) metrics[key] = spread;
    }
    const summary: ScenarioSummary = { scenario, runs: runs.length, metrics };
    const launch = averageBreakdowns(runs.flatMap((run) => (run.launch ? [run.launch] : [])));
    const card = averageBreakdowns(runs.flatMap((run) => (run.card ? [run.card] : [])));
    const coreData = averageCoreData(runs.flatMap((run) => (run.coreData ? [run.coreData] : [])));
    if (launch) summary.launch = launch;
    if (card) summary.card = card;
    if (coreData) summary.coreData = coreData;
    return summary;
}

/// Everything a performance run found, as summary.json holds it.
export interface PerformanceSummary {
    format: 1;
    createdAt: string;
    /// The commit the build was made from, and whether the tree had changes on top.
    commit: string;
    uncommittedChanges: boolean;
    /// When the build was made, and whether this run reused it (--skip-build).
    builtAt: string;
    reusedBuild: boolean;
    configuration: string;
    xcode: string;
    /// The Mac's processor and how many cores it has.
    mac: { cpu: string; cores: number };
    simulator: { name: string; os: string; udid: string };
    /// The card the deep links open.
    card: { name: string; code: string };
    runsPerScenario: number;
    settleSeconds: number;
    scenarios: ScenarioSummary[];
    runs: RunResult[];
}

function ms(value: number): string {
    return `${value.toFixed(1)} ms`;
}

function change(value: number, baseline: number): string {
    const difference = value - baseline;
    const percent = baseline === 0 ? "" : ` (${difference >= 0 ? "+" : ""}${((difference / baseline) * 100).toFixed(0)}%)`;
    return `${difference >= 0 ? "+" : ""}${difference.toFixed(1)} ms${percent}`;
}

function weightedTable(heading: string, rows: Weighted[], total: number): string[] {
    if (rows.length === 0) return [];
    return [
        `| ${heading} | ms per run | Share |`,
        "|---|---:|---:|",
        ...rows.map((row) => `| \`${row.name.replaceAll("|", "\\|")}\` | ${row.ms.toFixed(1)} | ${total > 0 ? `${((row.ms / total) * 100).toFixed(0)}%` : ""} |`),
        "",
    ];
}

function breakdownSection(breakdown: Breakdown): string[] {
    return [
        `#### ${breakdown.label}`,
        "",
        `${ms(breakdown.durationMs)} on average${breakdown.runs === undefined ? "" : ` over ${breakdown.runs} run${breakdown.runs === 1 ? "" : "s"}`}, of which the main thread was busy for ${ms(breakdown.mainThreadMs)}.`,
        "",
        ...weightedTable("App function, with what it called", breakdown.appFunctions, breakdown.mainThreadMs),
        ...weightedTable("Innermost app function", breakdown.innermostAppFunctions, breakdown.mainThreadMs),
        ...weightedTable("Library the time was in", breakdown.libraries, breakdown.mainThreadMs),
    ];
}

/// How a baseline was measured differently, in words: anything here makes
/// its medians a poor comparison.
export function baselineDifferences(summary: PerformanceSummary, baseline: PerformanceSummary): string[] {
    const differences: string[] = [];
    const compare = (now: string | number | undefined, then: string | number | undefined, describe: (value: string | number) => string) => {
        if (now !== then) differences.push(`${then === undefined ? "unknown" : describe(then)} (now ${now === undefined ? "unknown" : describe(now)})`);
    };
    compare(summary.configuration, baseline.configuration, (value) => `a ${value} build`);
    compare(summary.simulator.os, baseline.simulator.os, (value) => `iOS ${value}`);
    compare(summary.simulator.name, baseline.simulator.name, (value) => `the ${value} simulator`);
    compare(summary.xcode, baseline.xcode, (value) => `Xcode ${value}`);
    compare(summary.mac?.cpu, baseline.mac?.cpu, (value) => `${value}`);
    compare(summary.runsPerScenario, baseline.runsPerScenario, (value) => `${value} run${value === 1 ? "" : "s"} of each scenario`);
    compare(summary.settleSeconds, baseline.settleSeconds, (value) => `recorded for ${value} s`);
    return differences;
}

/// The report, in Markdown, for people and for an AI to review. With a
/// baseline, the results compare each median with the baseline's.
export function renderReport(summary: PerformanceSummary, baseline?: PerformanceSummary): string {
    const lines: string[] = [
        `# Performance report, ${summary.createdAt}`,
        "",
        `- **Build:** ${summary.configuration} from \`${summary.commit}\`${summary.uncommittedChanges ? " with uncommitted changes" : ""}, Xcode ${summary.xcode}, built ${summary.builtAt}${summary.reusedBuild ? " and reused (--skip-build)" : ""}`,
        `- **Simulator:** ${summary.simulator.name}, iOS ${summary.simulator.os} (${summary.simulator.udid}), on ${summary.mac.cpu} with ${summary.mac.cores} cores`,
        `- **Runs:** ${summary.runsPerScenario} of each scenario, taken in turn, each recorded for at least ${summary.settleSeconds} s after the app is let run or the link is sent`,
        `- **Deep links** open ${summary.card.name}: \`cards://cards/card/${encodeURIComponent(summary.card.code)}\``,
    ];
    if (baseline) {
        lines.push(`- **Baseline:** ${baseline.createdAt}, ${baseline.configuration} from \`${baseline.commit}\`${baseline.uncommittedChanges ? " with uncommitted changes" : ""}`);
        const differences = baselineDifferences(summary, baseline);
        if (differences.length > 0) lines.push(`- **The baseline is not like for like:** ${differences.join("; ")}.`);
    }
    lines.push("", "## Results", "", "Milliseconds from the start of each run; lower is better.", "");
    lines.push(baseline
        ? "| Scenario | Measure | Median | Min | Max | Runs | Baseline median | Change |\n|---|---|---:|---:|---:|---:|---:|---:|"
        : "| Scenario | Measure | Median | Min | Max | Runs |\n|---|---|---:|---:|---:|---:|");
    for (const scenario of summary.scenarios) {
        const before = baseline?.scenarios.find((item) => item.scenario === scenario.scenario);
        for (const key of metricKeys) {
            const spread = scenario.metrics[key];
            if (!spread) continue;
            const row = `| ${scenarioTitles[scenario.scenario]} | ${metricLabels[key]} | ${spread.median.toFixed(1)} | ${spread.min.toFixed(1)} | ${spread.max.toFixed(1)} | ${spread.runs} |`;
            const old = before?.metrics[key];
            lines.push(baseline ? `${row} ${old ? old.median.toFixed(1) : "–"} | ${old ? change(spread.median, old.median) : "–"} |` : row);
        }
    }

    lines.push(
        "",
        "## How it was measured",
        "",
        ...summary.scenarios.map((scenario) => `- **${scenarioTitles[scenario.scenario]}.** ${scenarioDescriptions[scenario.scenario]}`),
        "- **Start.** A cold run launches the app stopped (devicectl --start-stopped), attaches the trace, then lets it run; it starts when the process's initialisers begin, the first sample in `libSystem_initializer` or dyld's `runAllInitializers`. dyld's loading before that is left out: with Instruments attached, dyld in the simulator spends over a second reporting each image to it, time Instruments adds; on a phone, loading takes 15 to 65 ms. A warm run starts when its main thread first runs after the link is sent. The simulator's spawning and SpringBoard's work are left out either way, so these times are the app's.",
        "- **First frame** and **Responsive** are the ends of UIKit's ApplicationFirstFramePresentation and ApplicationFirstFramePresentationResponsive signposts (ApplicationActivation… from the background), the intervals Apple's launch metrics use.",
        "- **Card screen appears** is the card screen's onAppear, seen as its save of the card's last-viewed date: the first Core Data save on the main thread. **Card on screen** is the end of the next Core Animation commit.",
        "- **The main thread's time** comes from Time Profiler samples, one a millisecond, averaged over the runs. An app function counts once per sample, with everything it called, so nested functions overlap; the innermost app function and the library add up to the main thread's total.",
        "- **The store** is the screenshot cards (`-screenshotSeed`, seeded by a debug build), restored before every run, so each run starts from the same data. One traced launch after installing, not counted, warms the simulator's caches and Instruments.",
        "- **Mac load** in *Every run* is the Mac's load average over the minute before the run. Builds, tests or other simulators running at the same time slow the runs they overlap; trust the medians when the loads are alike, and rerun when one run's load and times stand out.",
        "- **A simulator is not a phone.** It runs on the Mac's processor, with the Mac's disk and memory, so the times are only comparable with other runs on this Mac. Confirm a change on a device (`make device`, then Instruments' App Launch template).",
        "- **Notifications.** A release build asks to send notifications on every run, as the seeded cards have places and simctl cannot answer the prompt; it comes up after the card is on screen.",
    );

    lines.push("", "## Where the main thread's time goes", "");
    for (const scenario of summary.scenarios) {
        if (!scenario.launch && !scenario.card) continue;
        lines.push(`### ${scenarioTitles[scenario.scenario]}`, "");
        if (scenario.launch) lines.push(...breakdownSection(scenario.launch));
        if (scenario.card) lines.push(...breakdownSection(scenario.card));
    }

    lines.push("## Core Data", "", "From the start of a run to its last milestone, per run.", "", "| Scenario | Fetches | Fetch time | On the main thread | Saves | Save time | On the main thread |", "|---|---:|---:|---:|---:|---:|---:|");
    for (const scenario of summary.scenarios) {
        const activity = scenario.coreData;
        if (!activity) continue;
        lines.push(`| ${scenarioTitles[scenario.scenario]} | ${activity.fetches.toFixed(1)} | ${ms(activity.fetchMs)} | ${ms(activity.mainThreadFetchMs)} | ${activity.saves.toFixed(1)} | ${ms(activity.saveMs)} | ${ms(activity.mainThreadSaveMs)} |`);
    }

    lines.push("", "## Every run", "", `| Scenario | Run | ${metricKeys.map((key) => metricLabels[key]).join(" | ")} | Mac load | Trace | Notes |`, `|---|---:|${metricKeys.map(() => "---:|").join("")}---:|---|---|`);
    for (const run of summary.runs) {
        const values = metricKeys.map((key) => {
            const value = run.milestones[key];
            return value === undefined ? "–" : value.toFixed(1);
        });
        lines.push(`| ${scenarioTitles[run.scenario]} | ${run.run} | ${values.join(" | ")} | ${run.macLoad === undefined ? "–" : run.macLoad.toFixed(1)} | \`${run.trace}\` | ${run.notes.join(" ").replaceAll("|", "\\|")} |`);
    }

    lines.push(
        "",
        "## Looking deeper",
        "",
        "- `open <trace>` opens a run in Instruments: the Time Profiler, os_signpost, Data Fetches and Data Saves tracks.",
        "- `xcrun xctrace export --input <trace> --toc` lists its tables; export one with `--xpath`, such as `'/trace-toc/run[@number=\"1\"]/data/table[@schema=\"time-profile\"]'` for the samples, `'/trace-toc/run[@number=\"1\"]/data/table[@schema=\"os-signpost\" and not(@category) and not(@subsystem)]'` for the signposts, or `core-data-fetch` and `core-data-save`.",
        "- `summary.json`, beside this report, holds every number in it, run by run.",
        "",
    );
    return lines.join("\n");
}
