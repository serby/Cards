// Builds the app and its tests once with the Xcode in .xcode-version, then runs
// test runs from lib/test-devices.ts, each on its own simulator and pinned iOS:
// by default the unit tests (iPhone 17, iOS 27.0) and the UI tests on the
// iPhone 17 on iOS 26.5, as `make test` does; --all for every run, as `make
// test-all` does; --run for chosen ones. The tests are built into a folder that
// runs on any Mac, with the build Xcode's XCTest (lib/built-tests.ts), and run
// from it; with --built, it runs a folder build-tests.ts made, as each CI job
// does, and builds nothing, so CI compiles once, with that one Xcode, whatever
// Xcode then runs the tests. The simulators are made ready while the build runs
// or the folder is read: a missing iOS runtime is downloaded from Apple and
// installed (scripts/lib/simulator.ts), and a missing simulator created. The UI
// tests run in parallel on clones of their simulator, a class at a time. A
// failing test runs once more, and one that fails twice fails the run. Each
// run's result bundle is kept, for CI to upload when it fails.
//
// Usage: node scripts/run-tests.ts [--run <key>]... [--all] [--built <dir>] [--workers <n>] [--device <model>] [--os <version>] [--results <dir>]
//   --run      a test run from lib/test-devices.ts, such as ui-ipad-26; repeat for more
//   --all      every test run
//   --built    tests build-tests.ts built, to run without building
//   --workers  simulator clones for the UI tests: 5, or 2 on CI
//   --device   another device type for a one-off run, such as "iPhone 17 Pro"
//   --os       another iOS for a one-off run, such as "27"
//   --results  where the result bundles go, /tmp/cards-tests unless given

import { existsSync, mkdirSync, readFileSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";
import { buildTests, testRunFile } from "./lib/built-tests.ts";
import { bootTestSimulator, type Simulator } from "./lib/simulator.ts";
import { everydayTestRuns, testRun, testRuns, xcodeVersionFor, type TestRun } from "./lib/test-devices.ts";
import { finished, pinnedXcodeVersion, start, useXcodeVersion } from "./lib/xcode.ts";

const usage = "Usage: node scripts/run-tests.ts [--run <key>]... [--all] [--built <dir>] [--workers <n>] [--device <model>] [--os <version>] [--results <dir>]";

let options: { run?: string[]; all: boolean; built?: string; workers?: string; device?: string; os?: string; results: string };
let runs: TestRun[];
try {
    options = parseArgs({
        options: {
            run: { type: "string", multiple: true },
            all: { type: "boolean", default: false },
            built: { type: "string" },
            workers: { type: "string" },
            device: { type: "string" },
            os: { type: "string" },
            results: { type: "string", default: "/tmp/cards-tests" },
        },
        allowPositionals: false,
    }).values as typeof options;
    runs = options.all ? [...testRuns] : (options.run?.length ? options.run : everydayTestRuns).map(testRun);
} catch (error) {
    console.error(`${message(error)}\n${usage}`);
    process.exit(2);
}

const workers = Number(options.workers ?? (process.env.CI ? 2 : 5));
if (!Number.isInteger(workers) || workers < 1) {
    console.error(`--workers takes a whole number of simulators.\n${usage}`);
    process.exit(2);
}

// The pinned Xcode builds, and runs the tests it built. Tests built earlier run
// with the Xcode their runs name, the same for every run chosen.
const pinned = pinnedXcodeVersion();
if (options.built) {
    const xcodes = [...new Set(runs.map((run) => xcodeVersionFor(run, pinned)))];
    if (xcodes.length > 1) {
        console.error(`These runs need different Xcodes to run them (${xcodes.join(", ")}): run them separately.`);
        process.exit(2);
    }
    if (xcodes[0] !== pinned) useXcodeVersion(xcodes[0]!);
}

/// A run with the one-off --device or --os applied to its simulator.
function withOverrides(run: TestRun): TestRun {
    const model = options.device?.trim();
    const os = options.os?.trim();
    if (!model && !os) return run;
    const { download, localOs, ...simulator } = run.simulator;
    return {
        ...run,
        simulator: { ...simulator, key: "one-off", model: model || simulator.model, os: os || simulator.os, purpose: "a one-off run", ...(os ? {} : { download, localOs }) },
    };
}
runs = runs.map(withOverrides);

function message(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
}

/// Runs xcodebuild without blocking, so the simulators keep getting ready.
function xcodebuild(args: string[]): Promise<void> {
    return finished(start("xcodebuild", args), `xcodebuild ${args[0]}`);
}

const resultsDir = resolve(options.results);
const builtDir = resolve(options.built ?? join(resultsDir, "built"));
const xctestrun = testRunFile(builtDir);

// Each simulator's progress is held back until the build is done, so it does
// not interleave with the build's output. Runs on the same simulator share it.
const logs = new Map<string, string>();
const simulators = new Map<string, Promise<Simulator>>();
for (const run of runs) {
    const id = `${run.simulator.model}|${run.simulator.os}`;
    if (simulators.has(id)) continue;
    logs.set(id, "");
    simulators.set(id, bootTestSimulator(run.simulator, { log: (text) => logs.set(id, logs.get(id) + text) }));
}
const building = options.built
    ? (existsSync(xctestrun) ? Promise.resolve() : Promise.reject(new Error(`${builtDir} holds no built tests: make them with node scripts/build-tests.ts --out ${builtDir}`)))
    : buildTests(builtDir);
const results = await Promise.allSettled([building, ...simulators.values()]);
for (const [id, log] of logs) console.log(`\n==> Simulator: ${id.replace("|", ", iOS ")}\n${log}`);
const problems = results.filter((result) => result.status === "rejected").map((result) => message((result as PromiseRejectedResult).reason));
if (problems.length > 0) {
    for (const problem of problems) console.error(`error: ${problem}`);
    process.exit(1);
}
const builtWith = readFileSync(join(builtDir, "built-with.txt"), "utf8").trim();
const runWith = options.built ? xcodeVersionFor(runs[0]!, pinned) : pinned;
console.log(`\n==> Tests built by ${builtWith}, run by Xcode ${runWith}, from ${builtDir}`);

mkdirSync(resultsDir, { recursive: true });
const summary: string[] = [];
let failed = false;
for (const run of runs) {
    const simulator = await simulators.get(`${run.simulator.model}|${run.simulator.os}`)!;
    const bundle = join(resultsDir, `${run.key}.xcresult`);
    // xcodebuild will not write over an earlier result bundle.
    rmSync(bundle, { recursive: true, force: true });
    const where = `${simulator.device} on iOS ${simulator.version}`;
    console.log(`\n==> ${run.suite === "unit" ? "Unit" : "UI"} tests (${run.key}) on ${where}`);
    const started = Date.now();
    try {
        await xcodebuild([
            "test-without-building",
            "-xctestrun", xctestrun,
            "-destination", `id=${simulator.udid}`,
            run.suite === "unit" ? "-only-testing:CardsTests" : "-only-testing:CardsUITests",
            ...(run.suite === "ui" ? ["-parallel-testing-enabled", "YES", "-parallel-testing-worker-count", String(workers)] : []),
            "-resultBundlePath", bundle,
            // The unit tests in English in the US, as CI has always run them. The
            // UI tests choose their own language and region when they launch the
            // app (UITestNavigation.swift), British English unless a test says.
            ...(run.suite === "unit" ? ["-testLanguage", "en", "-testRegion", "US"] : []),
            "-collect-test-diagnostics", "never",
            "-retry-tests-on-failure",
            "-test-iterations", "2",
        ]);
        summary.push(`passed  ${run.key} on ${where} in ${Math.round((Date.now() - started) / 1000)} s`);
    } catch (error) {
        failed = true;
        summary.push(`FAILED  ${run.key} on ${where} in ${Math.round((Date.now() - started) / 1000)} s: ${message(error)}. The result bundle is ${bundle}`);
    }
}
console.log(`\n==> Summary\n${summary.join("\n")}`);
process.exit(failed ? 1 : 0);
