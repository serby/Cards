// Measures how fast the app launches and opens a card from a link, in a
// simulator of its own, and writes a report for people and AI to review.
//
// It builds the app (release by default) and a debug build for the seed cards
// into build/performance/dd, kept apart from Xcode's build location so it
// never changes what Xcode, `make build` or another session has built. On the
// iPhone 17 (Cards performance) simulator, its own, it seeds the screenshot
// cards with the debug build, saves the store, installs the build to measure
// and launches it once, traced but not counted. Then it records each run with
// Instruments (Time Profiler, os_signpost, Data Fetches and Data Saves),
// restoring the store first so every run starts from the same data:
//
// - launch: the app is not running and opens on the list;
// - deep-link: the app is not running and cards://cards/card/<code> opens it on a card;
// - warm-deep-link: the app is in the background and the link brings it forward.
//
// A cold run launches the app stopped, attaches the trace and then lets it
// run, so the trace sees it from its first instruction. A warm run attaches
// while the app is in front, as Instruments cannot attach to an app iOS has
// suspended in the background. Links go through devicectl, as `simctl
// openurl` asks first. The runs take turns, so a slow spell on the Mac falls
// on every scenario alike, and a run that fails gets one more go.
//
// It writes build/performance/<date-time>/: report.md (lib/performance.ts
// says what it measures), summary.json with every number, and traces/ with
// every trace; build/performance/latest points at the newest. --baseline
// compares the medians with an earlier run's.
//
// Usage: node scripts/trace-performance.ts [--runs <n>] [--scenario <name>]... [--configuration Release|Debug] [--skip-build] [--settle <seconds>] [--card <name>] [--baseline <folder>] [--out <folder>]

import { execFileSync } from "node:child_process";
import { cpSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, unlinkSync, writeFileSync } from "node:fs";
import { cpus, loadavg, tmpdir } from "node:os";
import { basename, join, relative, resolve } from "node:path";
import { parseArgs } from "node:util";
import { logger, positiveInteger, runScript, UsageError } from "./lib/command-line.ts";
import {
    analyseRun,
    isCold,
    metricKeys,
    metricLabels,
    opensCard,
    type PerformanceSummary,
    renderReport,
    type RunResult,
    type Scenario,
    samplesFrom,
    scenarios,
    scenarioTitles,
    signpostsFrom,
    spansFrom,
    summarise,
} from "./lib/performance.ts";
import { findTestSimulator } from "./lib/simulator.ts";
import { automatedTestSimulatorWith, sameName } from "./lib/test-devices.ts";
import { builtProductsDir, capture, pinnedXcodeVersion, projectArgs, root, run } from "./lib/xcode.ts";
import { exportTable, startRecording, traceStartDate } from "./lib/xctrace.ts";

const usage = `Usage: node scripts/trace-performance.ts [options]

Builds the app, then traces cold launches and deep links to a card in the iPhone 17 (Cards performance) simulator and writes a report to build/performance/<date-time>/report.md.

Options:
  --runs <n>               Runs of each scenario (default 5)
  --scenario <name>        Only this scenario; repeat for more: ${scenarios.join(", ")} (default all)
  --configuration <name>   Release (default) or Debug
  --skip-build             Use the last build in build/performance instead of building
  --settle <seconds>       How long to record after the app is let run or the link is sent (default 6)
  --card <name>            The seeded card the deep links open (default the last in the list)
  --baseline <folder>      An earlier report's folder (or its summary.json) to compare with
  --out <folder>           Where to write the report (default build/performance/<date-time>)`;

const log = logger("trace-performance");

const bundleIdentifier = "net.serby.Cards";
/// Where the warm runs send the app, to put it in the background.
const otherApp = "com.apple.Preferences";
const model = "iPhone 17";
/// The newest iOS 27 that runs the model, as Paul's iPhone 17 simulator uses.
const os = "27";
const simulatorName = `${model} (Cards performance)`;
/// Where the screenshot cards' distances are measured from (ScreenshotSeed.location).
const location = "51.5091,-0.1963";

const performanceRoot = join(root, "build", "performance");
const derivedData = join(performanceRoot, "dd");
const seedFolder = join(performanceRoot, "seed");
const destination = "generic/platform=iOS Simulator";
/// What each run records.
const instruments = ["--template", "Time Profiler", "--instrument", "os_signpost", "--instrument", "Data Saves", "--instrument", "Data Fetches"];
/// How long a warm run gives the app to finish launching, untraced, before
/// attaching, and how long it leaves it in the background before the link.
const launchedMs = 4000;
const backgroundMs = 2000;
/// How long simctl may take to bring the other app forward, and devicectl to
/// send a link, which a warm run records through on top of the settle time.
const switchingMs = 3000;
const sendingMs = 3000;

interface Options {
    runs: number;
    scenarios: Scenario[];
    configuration: "Release" | "Debug";
    build: boolean;
    settleMs: number;
    card?: string;
    baseline?: string;
    out: string;
}

function options(argv: string[]): Options | undefined {
    const { values } = parseArgs({
        args: argv,
        options: {
            runs: { type: "string" },
            scenario: { type: "string", multiple: true },
            configuration: { type: "string", default: "Release" },
            "skip-build": { type: "boolean", default: false },
            settle: { type: "string" },
            card: { type: "string" },
            baseline: { type: "string" },
            out: { type: "string" },
            help: { type: "boolean", short: "h", default: false },
        },
    });
    if (values.help) {
        console.log(usage);
        return undefined;
    }
    const chosen = (values.scenario ?? [...scenarios]).map((name) => {
        const scenario = scenarios.find((item) => item === name.trim().toLowerCase());
        if (!scenario) throw new UsageError(`No scenario called ${name}. The scenarios are ${scenarios.join(", ")}`);
        return scenario;
    });
    const configuration = values.configuration === "Debug" ? "Debug" : values.configuration === "Release" ? "Release" : undefined;
    if (!configuration) throw new UsageError("--configuration is Release or Debug");
    const stamp = new Date().toISOString().replace(/\.\d+Z$/, "").replace("T", "-").replaceAll(":", "");
    const result: Options = {
        runs: positiveInteger(values.runs, 5, "--runs"),
        scenarios: [...new Set(chosen)],
        configuration,
        build: !values["skip-build"],
        settleMs: positiveInteger(values.settle, 6, "--settle") * 1000,
        out: resolve(values.out ?? join(performanceRoot, stamp)),
    };
    if (values.card) result.card = values.card;
    if (values.baseline) result.baseline = values.baseline;
    return result;
}

function sleep(milliseconds: number): Promise<void> {
    return new Promise((done) => setTimeout(done, milliseconds));
}

/// Runs an Xcode tool and ignores a failure, as when ending an app that is not running.
function attempt(command: string, args: string[]): void {
    try {
        run(command, args, { stdio: "ignore" });
    } catch {
        // Nothing to do: the step was only tidying up.
    }
}

/// The script's own simulator, created if there is none, and booted. Its own,
/// because each run uninstalls the app and replaces its data, which no one
/// else's simulator should have done to it.
function bootSimulator(): { udid: string; version: string } {
    const pick = findTestSimulator(automatedTestSimulatorWith({ model, os }));
    const list = JSON.parse(capture("xcrun", ["simctl", "list", "-j", "devices"])) as { devices: Record<string, { name: string; udid: string; isAvailable?: boolean }[]> };
    let udid = (list.devices[pick.runtime] ?? []).find((device) => device.isAvailable !== false && device.name === simulatorName)?.udid;
    if (!udid) {
        udid = capture("xcrun", ["simctl", "create", simulatorName, pick.deviceType, pick.runtime]).trim();
        log(`Created ${simulatorName} on iOS ${pick.version} (${udid}).`);
    }
    attempt("xcrun", ["simctl", "boot", udid]);
    run("xcrun", ["simctl", "bootstatus", udid, "-b"], { stdio: "ignore" });
    return { udid, version: pick.version };
}

function buildArguments(configuration: string): string[] {
    // IDEBuildLocationStyle=Unique overrides a custom build location
    // preference, so the products land in build/performance/dd.
    return ["-configuration", configuration, "-derivedDataPath", derivedData, "-IDEBuildLocationStyle=Unique"];
}

/// The app built for `configuration`, building it first unless `build` is false.
function app(configuration: string, build: boolean): string {
    if (build) {
        log(`Building ${configuration}…`);
        run("xcodebuild", [...projectArgs, ...buildArguments(configuration), "-destination", destination, "-quiet", "build"]);
    }
    const path = join(builtProductsDir(destination, buildArguments(configuration)), "Cards.app");
    if (!existsSync(path)) throw new Error(`No ${configuration} build at ${path}${build ? "" : ": run without --skip-build"}`);
    return path;
}

function terminate(udid: string, bundle = bundleIdentifier): void {
    attempt("xcrun", ["simctl", "terminate", udid, bundle]);
}

/// Installs `path` afresh: uninstalling first, as `simctl install` over a
/// copy can keep the old binary. Location is granted, so the cards' distances
/// show without asking.
function install(udid: string, path: string): void {
    terminate(udid);
    attempt("xcrun", ["simctl", "uninstall", udid, bundleIdentifier]);
    run("xcrun", ["simctl", "install", udid, path]);
    for (const service of ["location", "location-always"]) attempt("xcrun", ["simctl", "privacy", udid, "grant", service, bundleIdentifier]);
    run("xcrun", ["simctl", "location", udid, "set", location]);
}

/// The app's Application Support folder, where its store is.
function applicationSupport(udid: string): string {
    const container = capture("xcrun", ["simctl", "get_app_container", udid, bundleIdentifier, "data"]).trim();
    if (!container.includes(`/Devices/${udid}/`)) throw new Error(`Unexpected app container ${container}`);
    return join(container, "Library", "Application Support");
}

interface SeedCard {
    name: string;
    code: string;
}

/// The cards in a store, or none while it is still being created (no table
/// yet, or locked).
function cardsIn(store: string): SeedCard[] {
    if (!existsSync(store)) return [];
    try {
        const output = execFileSync("sqlite3", ["-readonly", "-json", store, "select ZNAME as name, ZCODE as code from ZCARDITEM order by ZORDER"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
        return output ? (JSON.parse(output) as SeedCard[]) : [];
    } catch {
        return [];
    }
}

/// Seeds the screenshot cards with the debug build and saves its store.
async function seed(udid: string, debugApp: string): Promise<SeedCard[]> {
    log("Seeding the screenshot cards…");
    install(udid, debugApp);
    run("xcrun", ["simctl", "launch", udid, bundleIdentifier, "-screenshotSeed"], { stdio: "ignore" });
    const store = join(applicationSupport(udid), "default.store");
    const deadline = Date.now() + 30_000;
    while (cardsIn(store).length === 0) {
        if (Date.now() > deadline) throw new Error("The debug build never saved the screenshot cards");
        await sleep(500);
    }
    // Long enough for the store's other writes, such as CloudKit's metadata, to finish.
    await sleep(3000);
    terminate(udid);
    rmSync(seedFolder, { recursive: true, force: true });
    cpSync(applicationSupport(udid), seedFolder, { recursive: true });
    return cardsIn(join(seedFolder, "default.store"));
}

/// Puts the seeded store back, so the run starts from the same data as the others.
function restoreStore(udid: string): void {
    terminate(udid);
    const folder = applicationSupport(udid);
    rmSync(folder, { recursive: true, force: true });
    cpSync(seedFolder, folder, { recursive: true });
}

/// Launches the app through devicectl, which opens a link without asking, and
/// returns its process ID. Stopped, it waits before its first instruction.
function launch(udid: string, link: string | undefined, stopped: boolean): number {
    const folder = mkdtempSync(join(tmpdir(), "cards-launch-"));
    try {
        const output = join(folder, "launch.json");
        run("xcrun", [
            "devicectl", "device", "process", "launch", "--device", udid,
            ...(stopped ? ["--start-stopped"] : []),
            ...(link ? ["--payload-url", link] : []),
            "--json-output", output, bundleIdentifier,
        ], { stdio: "ignore" });
        const pid = (JSON.parse(readFileSync(output, "utf8")) as { result?: { process?: { processIdentifier?: number } } }).result?.process?.processIdentifier;
        if (!pid) throw new Error("devicectl did not say which process it launched");
        return pid;
    } finally {
        rmSync(folder, { recursive: true, force: true });
    }
}

/// Records one cold run: the app starts stopped, the trace attaches, then the
/// app runs, for `settleMs`. Returns when it let the app run, in
/// milliseconds since 1970.
async function recordCold(udid: string, link: string | undefined, trace: string, settleMs: number): Promise<number> {
    restoreStore(udid);
    const pid = launch(udid, link, true);
    const recording = await startRecording([...instruments, "--device", udid, "--attach", String(pid)], trace, settleMs);
    try {
        const startedAt = Date.now();
        // Throws when iOS has already ended the waiting app.
        process.kill(pid, "SIGCONT");
        await recording.finished();
        terminate(udid);
        return startedAt;
    } catch (error) {
        await recording.cancel();
        throw error;
    }
}

/// Records one warm run: the app is launched and traced, sent to the
/// background, then brought back by the link. The trace attaches while the
/// app is in front, as Instruments cannot attach to one iOS has suspended.
/// Returns when the link was sent.
async function recordWarm(udid: string, link: string, trace: string, settleMs: number): Promise<number> {
    restoreStore(udid);
    const pid = launch(udid, undefined, false);
    await sleep(launchedMs);
    const recording = await startRecording([...instruments, "--device", udid, "--attach", String(pid)], trace, switchingMs + backgroundMs + sendingMs + settleMs);
    try {
        run("xcrun", ["simctl", "launch", udid, otherApp], { stdio: "ignore" });
        await sleep(backgroundMs);
        const sentAt = Date.now();
        launch(udid, link, false);
        await recording.finished();
        terminate(udid);
        terminate(udid, otherApp);
        return sentAt;
    } catch (error) {
        await recording.cancel();
        throw error;
    }
}

const tableXPath = (condition: string) => `/trace-toc/run[@number="1"]/data/table[${condition}]`;

function analyse(trace: string, scenario: Scenario, number: number, startedAt: number, out: string): RunResult {
    const data = {
        signposts: signpostsFrom(exportTable(trace, tableXPath(`@schema="os-signpost" and not(@category) and not(@subsystem)`))),
        samples: samplesFrom(exportTable(trace, tableXPath(`@schema="time-profile"`))),
        saves: spansFrom(exportTable(trace, tableXPath(`@schema="core-data-save"`))),
        fetches: spansFrom(exportTable(trace, tableXPath(`@schema="core-data-fetch"`))),
    };
    return analyseRun(data, { scenario, run: number, trace: relative(out, trace), notBeforeMs: startedAt - traceStartDate(trace) });
}

/// What a build was made from, kept beside it for --skip-build.
interface BuildSource {
    commit: string;
    /// Whether the tree had changes on top, tracked or untracked: the project
    /// compiles every file in Cards/, so a new file is part of the build.
    uncommittedChanges: boolean;
    builtAt: string;
}

const buildSourceFile = join(derivedData, "build-source.json");

/// What the build about to be made is made from (read before building, as
/// another session may commit while the runs go on), or what the last one was.
function buildSource(building: boolean): BuildSource {
    if (!building) {
        if (existsSync(buildSourceFile)) return JSON.parse(readFileSync(buildSourceFile, "utf8")) as BuildSource;
        return { commit: "unknown", uncommittedChanges: false, builtAt: "unknown" };
    }
    return {
        commit: git(["rev-parse", "--short", "HEAD"]) ?? "unknown",
        uncommittedChanges: (git(["status", "--porcelain"]) ?? "") !== "",
        builtAt: new Date().toISOString(),
    };
}

/// What git prints, or undefined outside a checkout.
function git(args: string[]): string | undefined {
    try {
        return execFileSync("git", args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    } catch {
        return undefined;
    }
}

function loadBaseline(path: string): PerformanceSummary {
    const file = path.endsWith(".json") ? path : join(path, "summary.json");
    if (!existsSync(file)) throw new UsageError(`No summary.json at ${file}`);
    return JSON.parse(readFileSync(file, "utf8")) as PerformanceSummary;
}

/// Points build/performance/latest at the report's folder, when it is in
/// build/performance. Anything there that is not a link is left alone.
function markLatest(out: string): void {
    if (resolve(out, "..") !== performanceRoot) return;
    const latest = join(performanceRoot, "latest");
    if (isLink(latest)) unlinkSync(latest);
    if (!existsSync(latest)) symlinkSync(basename(out), latest);
}

function isLink(path: string): boolean {
    try {
        return lstatSync(path).isSymbolicLink();
    } catch {
        return false;
    }
}

async function main(argv: string[]): Promise<number> {
    const chosen = options(argv);
    if (!chosen) return 0;
    const baseline = chosen.baseline ? loadBaseline(chosen.baseline) : undefined;

    const { udid, version } = bootSimulator();
    log(`Using ${simulatorName}, iOS ${version} (${udid}).`);
    const source = buildSource(chosen.build);
    const debugApp = app("Debug", chosen.build);
    const measuredApp = chosen.configuration === "Debug" ? debugApp : app(chosen.configuration, chosen.build);
    if (chosen.build) writeFileSync(buildSourceFile, `${JSON.stringify(source, null, 2)}\n`);

    const cards = await seed(udid, debugApp);
    const card = chosen.card ? cards.find((item) => sameName(item.name, chosen.card ?? "")) : cards.at(-1);
    if (!card) throw new UsageError(chosen.card ? `No seeded card called ${chosen.card}. The cards are ${cards.map((item) => item.name).join(", ")}` : "The seed has no cards");
    const link = `cards://cards/card/${encodeURIComponent(card.code)}`;

    install(udid, measuredApp);
    // The first launch after installing, and xctrace's first recording, are
    // slow enough to skew a run: a stopped app that waits too long for the
    // trace is ended by iOS. So one traced launch goes first, not counted.
    log("Launching once, traced but not counted, to warm the simulator's caches and Instruments…");
    const warmUp = mkdtempSync(join(tmpdir(), "cards-performance-"));
    try {
        await recordCold(udid, undefined, join(warmUp, "warm-up.trace"), chosen.settleMs);
    } catch (error) {
        log(`  the warm-up failed, which the runs can survive: ${(error as Error).message.split("\n")[0]}`);
        terminate(udid);
    } finally {
        rmSync(warmUp, { recursive: true, force: true });
    }

    const traces = join(chosen.out, "traces");
    mkdirSync(traces, { recursive: true });
    const results: RunResult[] = [];
    const measure = async (scenario: Scenario, number: number): Promise<RunResult> => {
        const trace = join(traces, `${scenario}-${number}.trace`);
        rmSync(trace, { recursive: true, force: true });
        const startedAt = isCold(scenario)
            ? await recordCold(udid, opensCard(scenario) ? link : undefined, trace, chosen.settleMs)
            : await recordWarm(udid, link, trace, chosen.settleMs);
        return analyse(trace, scenario, number, startedAt, chosen.out);
    };
    for (let number = 1; number <= chosen.runs; number += 1) {
        for (const scenario of chosen.scenarios) {
            log(`${scenarioTitles[scenario]}, run ${number} of ${chosen.runs}…`);
            const macLoad = loadavg()[0];
            let result: RunResult | undefined;
            // A run that fails, as when xctrace cannot attach, gets one more go.
            for (let attempt = 1; attempt <= 2 && !result; attempt += 1) {
                try {
                    result = await measure(scenario, number);
                } catch (error) {
                    terminate(udid);
                    terminate(udid, otherApp);
                    const message = (error as Error).message.split("\n").filter((line) => line.trim() !== "").slice(0, 2).join(" ");
                    log(`  failed${attempt === 1 ? ", trying again" : ""}: ${message}`);
                    if (attempt === 2) result = { scenario, run: number, trace: relative(chosen.out, join(traces, `${scenario}-${number}.trace`)), milestones: {}, notes: [`The run failed twice: ${message}`] };
                }
            }
            if (!result) continue;
            if (macLoad !== undefined) result.macLoad = macLoad;
            results.push(result);
            const measured = metricKeys.flatMap((key) => {
                const value = result.milestones[key];
                return value === undefined ? [] : [`${metricLabels[key].toLowerCase()} ${value.toFixed(1)} ms`];
            });
            log(`  ${[...measured, ...result.notes].join(", ") || "nothing measured"}`);
        }
    }

    const summary: PerformanceSummary = {
        format: 1,
        createdAt: new Date().toISOString(),
        commit: source.commit,
        uncommittedChanges: source.uncommittedChanges,
        builtAt: source.builtAt,
        reusedBuild: !chosen.build,
        configuration: chosen.configuration,
        xcode: pinnedXcodeVersion(),
        mac: { cpu: cpus()[0]?.model ?? "unknown", cores: cpus().length },
        simulator: { name: simulatorName, os: version, udid },
        card,
        runsPerScenario: chosen.runs,
        settleSeconds: chosen.settleMs / 1000,
        scenarios: chosen.scenarios.map((scenario) => summarise(results, scenario)),
        runs: results,
    };
    writeFileSync(join(chosen.out, "summary.json"), `${JSON.stringify(summary, null, 2)}\n`);
    const report = join(chosen.out, "report.md");
    writeFileSync(report, renderReport(summary, baseline));
    markLatest(chosen.out);

    for (const scenario of summary.scenarios) {
        const medians = metricKeys.flatMap((key) => {
            const spread = scenario.metrics[key];
            return spread ? [`${metricLabels[key].toLowerCase()} ${spread.median.toFixed(1)} ms`] : [];
        });
        log(`${scenarioTitles[scenario.scenario]}: ${medians.join(", ") || "nothing measured"} (median of ${scenario.runs})`);
    }
    console.log(report);
    return results.some((result) => result.milestones.firstFrameMs !== undefined || result.milestones.cardOnScreenMs !== undefined) ? 0 : 1;
}

if (import.meta.main) runScript("trace-performance", main);
